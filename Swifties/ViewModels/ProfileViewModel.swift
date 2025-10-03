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
    private let db: Firestore
    private let storage: Storage

    init(db: Firestore = .firestore(), storage: Storage = .storage()) {
        self.db = db
        self.storage = storage
    }

    func loadProfile(userID: String) async throws -> UserModel {
        let snapshot = try await db.collection("users").document(userID).getDocument()
        guard let data = snapshot.data() else {
            throw UserProfileRepositoryError.notFound
        }

        // Extract the nested maps
        guard let profile = data["profile"] as? [String: Any] else {
            throw UserProfileRepositoryError.decoding
        }
        
        guard let preferences = data["preferences"] as? [String: Any] else {
            throw UserProfileRepositoryError.decoding
        }
        
        guard let notifications = preferences["notifications"] as? [String: Any] else {
            throw UserProfileRepositoryError.decoding
        }
        
        guard let stats = data["stats"] as? [String: Any] else {
            throw UserProfileRepositoryError.decoding
        }

        // Safely parse fields from "profile"
        let name = profile["name"] as? String ?? "Unknown"
        let email = profile["email"] as? String ?? "Unknown"
        let major = profile["major"] as? String ?? "Unknown"
        let gender = profile["gender"] as? String ?? "Unknown"
        let favorite_categories = preferences["favorite_categories"] as? [String] ?? ["Unknown"]
        let completed_categories = preferences["completed_categories"] as? [String] ?? ["Unknown"]
        let free_time_slots = notifications["free_time_slots"] as? [String] ?? ["Unknown"]
        
        // Parse Dates
        let created = profile["created"] as? Date ?? Date()
        let last_active = profile["last_active"] as? Date ?? Date()
        let last_wish_me_luck: Date = {
            if let ts = stats["last_wish_me_luck"] as? Timestamp {
                return ts.dateValue()
            } else if let date = stats["last_wish_me_luck"] as? Date {
                return date
            } else {
                return Date()
            }
        }()

        // Firestore numbers can be Int, Int64, Double, or NSNumber. Normalize to Int.
        let age: Int = {
            if let v = profile["age"] as? Int { return v }
            if let v = profile["age"] as? NSNumber { return v.intValue }
            if let v = profile["age"] as? Double { return Int(v) }
            return 0
        }()
        let indoor_outdoor_score: Int = {
            if let v = preferences["indoor_outdoor_score"] as? Int { return v }
            if let v = preferences["indoor_outdoor_score"] as? NSNumber { return v.intValue }
            if let v = preferences["indoor_outdoor_score"] as? Double { return Int(v) }
            return 0
        }()
        let total_weekly_challenges: Int = {
            if let v = stats["total_weekly_challenges"] as? Int { return v }
            if let v = stats["total_weekly_challenges"] as? NSNumber { return v.intValue }
            if let v = stats["total_weekly_challenges"] as? Double { return Int(v) }
            return 0
        }()
        let streak_days: Int = {
            if let v = stats["streak_days"] as? Int { return v }
            if let v = stats["streak_days"] as? NSNumber { return v.intValue }
            if let v = stats["streak_days"] as? Double { return Int(v) }
            return 0
        }()
        let total_activities: Int = {
            if let v = stats["total_activities"] as? Int { return v }
            if let v = stats["total_activities"] as? NSNumber { return v.intValue }
            if let v = stats["total_activities"] as? Double { return Int(v) }
            return 0
        }()

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
        
        let profileModel = Profile(name: name,
                                   email: email,
                                   gender: gender,
                                   avatarURL: resolvedImageURL,
                                   created: created,
                                   lastActive: last_active,
                                   age: age,
                                   major: major)
        let preferencesModel = Preferences(indoorOutdoorScore: indoor_outdoor_score,
                                           favoriteCategories: favorite_categories,
                                           completedCategories: completed_categories,
                                           notifications: Notifications(freeTimeSlots: free_time_slots))
        let statsModel = Stats(lastWishMeLuck: last_wish_me_luck,
                               totalWeeklyChallenges: total_weekly_challenges,
                               streakDays: streak_days,
                               totalActivities: total_activities)

        return UserModel(
            profile: profileModel, preferences: preferencesModel, stats: statsModel
        )
    }
}


@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserModel?
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

