//
//  ProfileViewModel.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 1/10/25.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

/// Errors that can occur when loading a user profile using two possible cases
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
/// and resolves a Firebase Storage path into a public download URL to be used in-app.
final class UserProfileRepository {
    let db = Firestore.firestore(database: "default")
    private let storage: Storage

    init(db: Firestore = .firestore(), storage: Storage = .storage()) {
        //self.db = db
        self.storage = storage
    }

    func loadProfile(userID: String) async throws -> UserProfile {
        let snapshot = try await db.collection("users").document(userID).getDocument()
        guard let data = snapshot.data() else {
            throw UserProfileRepositoryError.notFound
        }

        // Extract the nested "profile" map
        guard let profile = data["profile"] as? [String: Any] else {
            throw UserProfileRepositoryError.decoding
        }

        // Safely parse fields from "profile"
        let name = profile["name"] as? String ?? "Unknown"
        let major = profile["major"] as? String ?? "Unknown"

        // Firestore numbers can be Int, Int64, Double, or NSNumber. Normalize to Int.
        let age: Int = {
            if let v = profile["age"] as? Int { return v }
            if let v = profile["age"] as? NSNumber { return v.intValue }
            if let v = profile["age"] as? Double { return Int(v) }
            return 0
        }()

        let personality = profile["indoor_outdoor_score"] as? String ?? "Unknown"
        let preferences = profile["favorite_categories"] as? [String] ?? ["Unknown"]

        // Image resolution priority: imageURL (absolute) -> imagePath (resolve via Storage)
        var resolvedImageURL: String?
        if let imagePath = profile["avatar_url"] as? String {
            do {
                let ref = storage.reference(withPath: imagePath)
                let url = try await ref.downloadURL()
                resolvedImageURL = url.absoluteString
            } catch {
                resolvedImageURL = nil // Don't fail whole fetch for image resolution issues
            }
        } else {
            resolvedImageURL = nil
        }

        return UserProfile(
            id: userID,
            name: name,
            avatar_url: resolvedImageURL,
            major: major,
            age: age,
            indoor_outdoor_score: personality,
            preferences: preferences
        )
    }
}


@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: UserProfileRepository

    init(repository: UserProfileRepository? = nil) {
        if let repository {
            self.repository = repository
        } else {
            self.repository = UserProfileRepository()
        }
    }

    func loadProfile(userID: String? = Auth.auth().currentUser?.uid) {
        guard let uid = userID else {
            self.errorMessage = "You are not logged in."
            self.isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loaded = try await repository.loadProfile(userID: uid)
                self.profile = loaded
                self.isLoading = false
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

