//
//  UserModel.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 1/10/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Root User document
struct UserModel: Identifiable, Codable {
    @DocumentID var id: String?   // Firestore doc ID (same as uid)
    var profile: Profile
    var preferences: Preferences
    var stats: Stats
}

// MARK: - Profile
struct Profile: Codable {
    var name: String
    var email: String
    var gender: String
    var avatarURL: String?
    var created: Date
    var lastActive: Date
    var age: Int
    var major: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case email
        case gender
        case avatarURL = "avatar_url"
        case created
        case lastActive = "last_active"
        case age
        case major
    }
}

// MARK: - Preferences
struct Preferences: Codable {
    var indoorOutdoorScore: Int
    var favoriteCategories: [String]
    var completedCategories: [String]
    var notifications: Notifications
    
    enum CodingKeys: String, CodingKey {
        case indoorOutdoorScore = "indoor_outdoor_score"
        case favoriteCategories = "favorite_categories"
        case completedCategories = "completed_categories"
        case notifications
    }
}

// MARK: - Notifications
struct Notifications: Codable {
    var freeTimeSlots: [String]
    
    enum CodingKeys: String, CodingKey {
        case freeTimeSlots = "free_time_slots"
    }
}

// MARK: - Stats
struct Stats: Codable {
    var lastWishMeLuck: Date
    var totalWeeklyChallenges: Int
    var streakDays: Int
    var totalActivities: Int
    
    enum CodingKeys: String, CodingKey {
        case lastWishMeLuck = "last_wish_me_luck"
        case totalWeeklyChallenges = "total_weekly_challenges"
        case streakDays = "streak_days"
        case totalActivities = "total_activities"
    }
}

