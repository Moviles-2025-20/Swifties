import Combine
import Foundation
import FirebaseFirestore
import UIKit

final class CommentSubmitCoordinator {
    static let shared = CommentSubmitCoordinator()

    @Published private(set) var isConnected: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var commentViewModel = CommentViewModel()
    private lazy var networkMonitor = NetworkMonitorService.shared
    private lazy var cache = CommentCacheService.shared
    private lazy var realmStorage = CommentRealmStorage.shared
    private let queue = DispatchQueue(label: "CommentSubmitCoordinator.queue")

    private init() {
        // Delay subscription to allow init to complete
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.observeNetworkChanges()
        }
    }

    private func observeNetworkChanges() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                print("Network connectivity changed: \(connected)")
                self.isConnected = connected
                if connected {
                    Task { await self.syncPendingComments() }
                }
            }
            .store(in: &cancellables)
    }

    public func submitOfflineFirst(payload: CommentViewModel.SubmissionPayload) async throws -> Result<Void, Error> {
        let localId = UUID().uuidString
        let createdDate = Date()
        
        let comment = Comment(
            id: localId,
            created: createdDate,
            eventId: payload.eventId,
            userId: payload.userId,
            metadata: Metadata(imageURL: nil, title: payload.title, text: payload.text),
            rating: payload.rating,
            emotion: payload.emotion
        )

        print("Submitting comment offline-first with localId \(localId)")
        
        // Optional image data — encode only if image exists
        var imageData: Data? = nil
        if let image = payload.image {
            imageData = image.jpegData(compressionQuality: 0.85)
            if imageData == nil {
                // If encoding fails, surface an error
                return .failure(NSError(domain: "CommentUploadCoordinator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image for offline save."]))
            }
        }
        
        // Save combined comment + optional image bytes to cache
        let cached = CachedComment(localId: localId, comment: comment, imageData: imageData)
        cache.set(cached, for: localId)
        
        // Create StoredComment to save with image
        let storedMetadata = StoredMetadata(image: imageData, title: payload.title, text: payload.text)
        let storedComment = StoredComment(
            id: localId,
            created: createdDate,
            eventId: payload.eventId,
            userId: payload.userId,
            metadata: storedMetadata,
            rating: payload.rating,
            emotion: payload.emotion
        )

        // Schedule saving to Realm after small delay to avoid race conditions
        queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.realmStorage.save(comment: storedComment, id: localId)
            print("Persisted comment to Realm with localId \(localId)")
        }

        // TODO: Check for race condition in saving
        if networkMonitor.isConnected {
            print("Online: attempting to submit comment with localId \(localId) to backend")
            do {
                try await commentViewModel.onlineSubmit(payload)
                print("Submission succeeded for localId \(localId), cleaning up cache and realm")
                cache.remove(id: localId)
                queue.async() {
                    self.realmStorage.remove(id: localId)
                }
                return .success(())
            } catch {
                print("Submission failed for localId \(localId), keeping offline copy: \(error)")
                return .failure(error)
            }
        } else {
            print("Offline: saved comment with localId \(localId) for later submission")
            return .success(())
        }
    }

    @MainActor
    private func syncPendingComments() async {
        print("Syncing pending comments...")

        let pendingComments = await realmStorage.loadAll()
        guard !pendingComments.isEmpty else {
            print("No pending comments to sync")
            return
        }

        for stored in pendingComments {
            // Expectation: `stored` contains at least: id, eventId, userId, metadata.title, metadata.text, rating, emotion, and optional imageData
            // This matches the info we saved above via realmStorage.save(comment:id:image:)
            let image: UIImage?
            if let imageData = stored.metadata.image {
                image = UIImage(data: imageData)
            } else {
                image = nil
            }

            // Build a SubmissionPayload that includes the re-created UIImage (so onlineSubmit will upload it)
            let payload = CommentViewModel.SubmissionPayload(
                eventId: stored.eventId,
                userId: stored.userId,
                title: stored.metadata.title,
                text: stored.metadata.text,
                image: image,
                rating: stored.rating ?? 0,
                emotion: stored.emotion ?? ""
            )
            
            print("Attempting to resubmit comment (local id: \(stored.id ?? "unknown"), eventId: \(stored.eventId))")

            do {
                try await commentViewModel.submit(payload)
                print("Resubmission succeeded, removing from cache and realm")
                        
                // Remove by stored id (ensure stored.id exists)
                if let id = stored.id {
                    cache.remove(id: id)
                    realmStorage.remove(id: id)
                } else {
                    // fallback: try to remove by other means or log
                    print("Warning: stored comment has no id; cannot remove from cache/realm automatically.")
                }
            } catch {
                print("Resubmission failed for id \(stored.id ?? "unknown"): \(error)")
            }
        }
    }
}
