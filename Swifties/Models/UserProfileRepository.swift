//
//  UserProfileRepository.swift
//  Swifties
//
//  Created by Juan Esteban Vásquez on 01/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

/// Abstraction for fetching user profile data.
protocol UserProfileRepository {
    /// Loads the profile for the given user id.
    /// - Parameter userID: The user's unique identifier.
    /// - Returns: A `UserProfile` if found.
    func loadProfile(userID: String) async throws -> UserProfile
}

/// Errors that can occur when loading a user profile
enum UserProfileRepositoryError: LocalizedError {
    case notFound
    case decoding

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No profile found for this user."
        case .decoding:
            return "Failed to decode profile data."
        }
    }
}

/// Firebase-backed implementation of `UserProfileRepository` that reads from Firestore
/// and optionally resolves a Firebase Storage path into a public download URL.
final class FirebaseUserProfileRepository: UserProfileRepository {
    private let db: Firestore
    private let storage: Storage

    init(db: Firestore = .firestore(), storage: Storage = .storage()) {
        self.db = db
        self.storage = storage
    }

    func loadProfile(userID: String) async throws -> UserProfile {
        let snapshot = try await db.collection("users").document(userID).getDocument()
        guard let data = snapshot.data() else {
            throw UserProfileRepositoryError.notFound
        }

        // Parse fields with safe fallbacks
        let name = data["name"] as? String ?? "Unknown"
        let major = data["major"] as? String ?? "—"
        let age = (data["age"] as? Int) ?? (data["age"] as? NSNumber)?.intValue ?? 0
        let personality = data["personality"] as? String ?? "—"
        let preferences = data["preferences"] as? [String] ?? []

        // Image resolution priority: imageURL (absolute) -> imagePath (resolve via Storage)
        var resolvedImageURL: String? = data["imageURL"] as? String
        if resolvedImageURL == nil, let imagePath = data["imagePath"] as? String {
            do {
                let ref = storage.reference(withPath: imagePath)
                let url = try await ref.downloadURL()
                resolvedImageURL = url.absoluteString
            } catch {
                // If resolving fails, keep image as nil rather than failing whole profile fetch
                resolvedImageURL = nil
            }
        }

        return UserProfile(
            id: userID,
            name: name,
            imageURL: resolvedImageURL,
            major: major,
            age: age,
            personality: personality,
            preferences: preferences
        )
    }
}
