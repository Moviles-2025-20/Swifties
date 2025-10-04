// CommentViewModel.swift
// Handles creating comment documents and uploading optional images to Firebase Storage.

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class CommentViewModel {
    private let db = Firestore.firestore(database: "default")
    private let storage = Storage.storage()

    struct SubmissionPayload {
        let eventId: String
        let userId: String
        let title: String
        let text: String
        let image: UIImage?
        let rating: Int?
        let emotion: String?
    }

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
    func toFirestore(comment: Comment) -> [String: Any] {
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
            throw NSError(domain: "CommentRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image."])
        }
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.putData(data, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        let url = try await ref.downloadURL()
        return url.absoluteString
    }
    
    // MARK: Functions used to solve word counts and limits
    /// Helper to tokenize a string into words, splitting on whitespace, newlines, and punctuation.
    private func tokenizeWords(from text: String) -> [String] {
        return text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    func currentWordCount(reviewDescription: String) -> Int {
        return tokenizeWords(from: reviewDescription).count
    }

    func enforceWordLimit(reviewDescription: String, wordLimit: Int) -> String {
        let words = tokenizeWords(from: reviewDescription)
        let limitedWords = words.prefix(wordLimit)
        let reconstructed = limitedWords.joined(separator: " ")
        if words.count > wordLimit {
            return reconstructed
        }
        return reviewDescription
    }
}
