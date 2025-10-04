// CommentViewModel.swift
// Handles creating comment documents and uploading optional images to Firebase Storage.

import Combine
import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class CommentViewModel: ObservableObject {
    private let db = Firestore.firestore(database: "default")
    private let storage = Storage.storage()

    struct SubmissionPayload {
        let eventId: String
        let userId: String
        let title: String
        let text: String
        let image: UIImage?
        let rating: Int
        let emotion: String
    }
    
    // Precompiled regex for faster loading times
    private static var wordRegex: NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: "\\S+", options: [])
        } catch {
            // Log the issue for debugging
            print("⚠️ Failed to compile wordRegex: \(error). Using fallback regex.")
            
            // Fallback to a safe, permissive pattern (matches any non-empty string)
            if let fallback = try? NSRegularExpression(pattern: ".+", options: []) {
                return fallback
            } else {
                // If even the fallback fails, return a regex that matches nothing
                print("⚠️ Fallback regex also failed to compile. Returning a regex that matches nothing.")
                // Return a static regex that matches nothing as a last resort
                return CommentViewModel.matchesNothingRegex
        }
    }

    // Static regex that matches nothing, used as a last resort fallback
    private static let matchesNothingRegex: NSRegularExpression = {
        // "a^" is a pattern that will never match anything
        return (try? NSRegularExpression(pattern: "a^", options: [])) ?? NSRegularExpression()
    }()
    func submit(_ payload: SubmissionPayload) async throws {
        // Create a new document reference first so we can use its ID for the storage path
        let docRef = db.collection("comments").document()

        // Create and identify the URL for the image using document's ID
        var imageURLString: String? = nil
        if let image = payload.image {
            let path = "comments/\(docRef.documentID).jpg"
            imageURLString = try await uploadImage(image, toPath: path)
        }

        let comment = Comment(
            created: Date(),
            eventId: payload.eventId,
            userId: payload.userId,
            metadata: .init(imageURL: imageURLString, title: payload.title, text: payload.text),
            rating: payload.rating,
            emotion: payload.emotion
        )

        try await docRef.setData(toFirestore(comment: comment))
    }
    
    // Firestore payload
    private func toFirestore(comment: Comment) -> [String: Any] {
        var metadataDict: [String: Any] = [
            "title": comment.metadata.title,
            "text": comment.metadata.text,
        ]
        if let imageURL = comment.metadata.imageURL { metadataDict["image_url"] = imageURL }

        return [
            "created": Timestamp(date: comment.created),
            "event_id": comment.eventId,
            "user_id": comment.userId,
            "metadata": metadataDict,
            "rating": comment.rating as Any,
            "emotion": comment.emotion as Any
        ]
    }

    // MARK: - Helpers
    private func uploadImage(_ image: UIImage, toPath path: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "CommentViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image."])
        }
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)

        let url = try await ref.downloadURL()
        return url.absoluteString
    }
    
    // MARK: Functions used to solve word counts and limits
    /// Returns the number of words in the given string, using the same logic as enforceWordLimit.
    func currentWordCount(reviewDescription: String) -> Int {
        let regex = CommentViewModel.wordRegex
        let nsText = reviewDescription as NSString
        let matches = regex.matches(in: reviewDescription, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.count
    }

    func enforceWordLimit(reviewDescription: String, wordLimit: Int) -> String {
        // Use regex to find word ranges, then cut the string at the end of the Nth word
        let regex = CommentViewModel.wordRegex
        let nsText = reviewDescription as NSString
        let matches = regex.matches(in: reviewDescription, options: [], range: NSRange(location: 0, length: nsText.length))
        if matches.count > wordLimit, let lastWordRange = matches.prefix(wordLimit).last?.range {
            // The end of the Nth word
            let endIndex = lastWordRange.location + lastWordRange.length
            let limitedText = nsText.substring(to: endIndex)
            return limitedText
        }
        return reviewDescription
    }
}
