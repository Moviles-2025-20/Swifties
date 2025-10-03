//
//  UserPreferences.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//
// UserPreferences.swift
import Foundation
import FirebaseFirestore

struct UserData: Codable {
    var preferences: Preferences
    var profile: Profile
    var stats: UserStats

    struct Preferences: Codable {
        var indoorOutdoorScore: Int
        var favoriteCategories: [String]
        var completedCategories: [String]
        var notifications: NotificationSettings

        enum CodingKeys: String, CodingKey {
            case indoorOutdoorScore = "indoor_outdoor_score"
            case favoriteCategories = "favorite_categories"
            case completedCategories = "completed_categories"
            case notifications
        }
    }

    struct NotificationSettings: Codable {
        var freeTimeSlots: [[String:String]]

        enum CodingKeys: String, CodingKey {
            case freeTimeSlots = "free_time_slots"
        }
    }

    struct Profile: Codable {
        var name: String
        var email: String
        var avatarUrl: String?   // allow nil when Auth has no photo
        var created: Timestamp
        var lastActive: Timestamp
        var major: String
        var age: Int
        var gender: String?      

        enum CodingKeys: String, CodingKey {
            case name, email
            case avatarUrl = "avatar_url"
            case created
            case lastActive = "last_active"
            case major, age, gender
        }
    }

    struct UserStats: Codable {
        var lastWishMeLuck: Timestamp?
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
}
