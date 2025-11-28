//
//  Badge.swift
//  Swifties
//
//  Badge Model and Related Structures
//

import Foundation
import RealmSwift

// MARK: - Badge Model (Main)
struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rarity: BadgeRarity
    let criteriaType: CriteriaType
    let criteriaValue: Int
    let isSecret: Bool
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity
        case criteriaType, criteriaValue, isSecret
        case createdAt, updatedAt
    }
}

// MARK: - User Badge Progress
struct UserBadge: Identifiable, Codable {
    let id: String
    let userId: String
    let badgeId: String
    var progress: Int
    var isUnlocked: Bool
    var earnedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId, badgeId, progress, isUnlocked, earnedAt
    }
}

// MARK: - Badge Rarity
enum BadgeRarity: String, Codable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var color: String {
        switch self {
        case .common: return "gray"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
}

// MARK: - Criteria Type
enum CriteriaType: String, Codable {
    case eventsAttended = "events_attended"
    case activitiesCompleted = "activities_completed"
    case weeklyChallenges = "weekly_challenges"
    
    // 🆕 Nuevos criterios
    case morningActivities = "morning_activities"
    case nightActivities = "night_activities"
    case allDayWarrior = "all_day_warrior"
    case firstComment = "first_comment"
    case commentsLeft = "comments_left"
    case firstWeeklyChallenge = "first_weekly_challenge"
    
    var displayName: String {
        switch self {
        case .eventsAttended: return "Events Attended"
        case .activitiesCompleted: return "Activities Completed"
        case .weeklyChallenges: return "Weekly Challenges"
        case .morningActivities: return "Morning Activities"
        case .nightActivities: return "Night Activities"
        case .allDayWarrior: return "All-Day Warrior"
        case .firstComment: return "First Comment"
        case .commentsLeft: return "Comments Left"
        case .firstWeeklyChallenge: return "First Weekly Challenge"
        }
    }
}

// MARK: - Badge with Progress (Combined View Model)
struct BadgeWithProgress: Identifiable {
    let badge: Badge
    let userBadge: UserBadge
    
    var id: String { badge.id }
    var progressPercentage: Int {
        min(100, (userBadge.progress * 100) / badge.criteriaValue)
    }
}

// MARK: - Realm Models

class RealmBadge: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var name: String
    @Persisted var badgeDescription: String
    @Persisted var icon: String
    @Persisted var rarity: String
    @Persisted var criteriaType: String
    @Persisted var criteriaValue: Int
    @Persisted var isSecret: Bool
    @Persisted var createdAt: String
    @Persisted var updatedAt: String
    
    convenience init(from badge: Badge) {
        self.init()
        self.id = badge.id
        self.name = badge.name
        self.badgeDescription = badge.description
        self.icon = badge.icon
        self.rarity = badge.rarity.rawValue
        self.criteriaType = badge.criteriaType.rawValue
        self.criteriaValue = badge.criteriaValue
        self.isSecret = badge.isSecret
        self.createdAt = badge.createdAt
        self.updatedAt = badge.updatedAt
    }
    
    func toBadge() -> Badge {
        Badge(
            id: id,
            name: name,
            description: badgeDescription,
            icon: icon,
            rarity: BadgeRarity(rawValue: rarity) ?? .common,
            criteriaType: CriteriaType(rawValue: criteriaType) ?? .eventsAttended,
            criteriaValue: criteriaValue,
            isSecret: isSecret,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

class RealmUserBadge: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var userId: String
    @Persisted var badgeId: String
    @Persisted var progress: Int
    @Persisted var isUnlocked: Bool
    @Persisted var earnedAt: Date?
    
    convenience init(from userBadge: UserBadge) {
        self.init()
        self.id = userBadge.id
        self.userId = userBadge.userId
        self.badgeId = userBadge.badgeId
        self.progress = userBadge.progress
        self.isUnlocked = userBadge.isUnlocked
        self.earnedAt = userBadge.earnedAt
    }
    
    func toUserBadge() -> UserBadge {
        UserBadge(
            id: id,
            userId: userId,
            badgeId: badgeId,
            progress: progress,
            isUnlocked: isUnlocked,
            earnedAt: earnedAt
        )
    }
}

class RealmBadgeCache: Object {
    @Persisted(primaryKey: true) var userId: String
    @Persisted var badges: List<RealmBadge>
    @Persisted var userBadges: List<RealmUserBadge>
    @Persisted var lastUpdated: Date
}
