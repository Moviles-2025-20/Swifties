//
//  BadgeDetailModels.swift
//  Swifties
//
//  Models for Badge Detail
//

import Foundation
import RealmSwift

// MARK: - Badge Detail (Main Model)
struct BadgeDetail: Identifiable {
    let id: String
    let badge: Badge
    let userBadge: UserBadge
    let totalUsersWithBadge: Int
    let completionRate: Int
    
    var progressPercentage: Int {
        guard badge.criteriaValue > 0 else { return 0 }
        let percentage = (userBadge.progress * 100) / badge.criteriaValue
        return min(percentage, 100)
    }
}

// MARK: - Realm Objects for Local Storage

class RealmBadgeDetail: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var userId: String
    @Persisted var badgeId: String
    
    // Badge Info
    @Persisted var badgeName: String
    @Persisted var badgeDescription: String
    @Persisted var badgeIcon: String
    @Persisted var badgeRarity: String
    @Persisted var criteriaType: String
    @Persisted var criteriaValue: Int
    @Persisted var isSecret: Bool
    
    // User Badge Info
    @Persisted var progress: Int
    @Persisted var isUnlocked: Bool
    @Persisted var earnedAt: Date?
    
    // Stats
    @Persisted var totalUsersWithBadge: Int
    @Persisted var completionRate: Int
    
    // Metadata
    @Persisted var cachedAt: Date
    
    convenience init(detail: BadgeDetail, userId: String) {
        self.init()
        self.id = "\(userId)_\(detail.badge.id)"
        self.userId = userId
        self.badgeId = detail.badge.id
        
        self.badgeName = detail.badge.name
        self.badgeDescription = detail.badge.description
        self.badgeIcon = detail.badge.icon
        self.badgeRarity = detail.badge.rarity.rawValue
        self.criteriaType = detail.badge.criteriaType.rawValue
        self.criteriaValue = detail.badge.criteriaValue
        self.isSecret = detail.badge.isSecret
        
        self.progress = detail.userBadge.progress
        self.isUnlocked = detail.userBadge.isUnlocked
        self.earnedAt = detail.userBadge.earnedAt
        
        self.totalUsersWithBadge = detail.totalUsersWithBadge
        self.completionRate = detail.completionRate
        
        self.cachedAt = Date()
    }
    
    func toBadgeDetail() -> BadgeDetail? {
        guard let rarity = BadgeRarity(rawValue: badgeRarity),
              let criteriaTypeEnum = CriteriaType(rawValue: criteriaType) else {
            return nil
        }
        
        let badge = Badge(
            id: badgeId,
            name: badgeName,
            description: badgeDescription,
            icon: badgeIcon,
            rarity: rarity,
            criteriaType: criteriaTypeEnum,
            criteriaValue: criteriaValue,
            isSecret: isSecret,
            createdAt: "",
            updatedAt: ""
        )
        
        let userBadge = UserBadge(
            id: "\(userId)_\(badgeId)",
            userId: userId,
            badgeId: badgeId,
            progress: progress,
            isUnlocked: isUnlocked,
            earnedAt: earnedAt
        )
        
        return BadgeDetail(
            id: badgeId,
            badge: badge,
            userBadge: userBadge,
            totalUsersWithBadge: totalUsersWithBadge,
            completionRate: completionRate
        )
    }
}
