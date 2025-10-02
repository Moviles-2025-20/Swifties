//
//  UserPreferences.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//

import Foundation
import FirebaseFirestore

// Estructura principal del usuario
struct UserData: Codable {
    let preferences: Preferences
    let profile: Profile
    let stats: UserStats

    struct Preferences: Codable {
        let indoorOutdoorScore: Int
        let favoriteCategories: [String]
        let completedCategories: [String]
        let notifications: NotificationSettings

        enum CodingKeys: String, CodingKey {
            case indoorOutdoorScore = "indoor_outdoor_score"
            case favoriteCategories = "favorite_categories"
            case completedCategories = "completed_categories"
            case notifications
        }
    }

    struct NotificationSettings: Codable {
        let freeTimeSlots: [String]

        enum CodingKeys: String, CodingKey {
            case freeTimeSlots = "free_time_slots"
        }
    }

    struct Profile: Codable {
        let name: String
        let email: String
        let avatarUrl: String
        let created: Timestamp
        let lastActive: Timestamp
        let major: String
        let age: Int

        enum CodingKeys: String, CodingKey {
            case name, email
            case avatarUrl = "avatar_url"
            case created
            case lastActive = "last_active"
            case major, age
        }
    }

    struct UserStats: Codable {
        let lastWishMeLuck: Timestamp?
        let totalWeeklyChallenges: Int
        let streakDays: Int
        let totalActivities: Int

        enum CodingKeys: String, CodingKey {
            case lastWishMeLuck = "last_wish_me_luck"
            case totalWeeklyChallenges = "total_weekly_challenges"
            case streakDays = "streak_days"
            case totalActivities = "total_activities"
        }
    }
}
