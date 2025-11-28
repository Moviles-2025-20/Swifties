//
//  BadgeDetailNetworkService.swift
//  Swifties
//
//  Layer 3: Network Service for Badge Detail
//

import Foundation
import FirebaseFirestore

class BadgeDetailNetworkService {
    static let shared = BadgeDetailNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    // MARK: - Fetch Badge Detail
    
    func fetchBadgeDetail(badgeId: String, userId: String, completion: @escaping (Result<BadgeDetail, Error>) -> Void) {
        print("🌐 Fetching badge detail from network: \(badgeId)")
        
        let group = DispatchGroup()
        
        var badge: Badge?
        var userBadge: UserBadge?
        var totalUsersWithBadge = 0
        var totalUsers = 0
        var fetchError: Error?
        
        // 1. Fetch Badge
        group.enter()
        db.collection("badges").document(badgeId).getDocument { snapshot, error in
            if let error = error {
                fetchError = error
                group.leave()
                return
            }
            
            guard let data = snapshot?.data(),
                  let name = data["name"] as? String,
                  let description = data["description"] as? String,
                  let icon = data["icon"] as? String,
                  let rarityStr = data["rarity"] as? String,
                  let criteriaTypeStr = data["criteriaType"] as? String,
                  let criteriaValue = data["criteriaValue"] as? Int,
                  let isSecret = data["isSecret"] as? Bool,
                  let createdAt = data["createdAt"] as? String,
                  let updatedAt = data["updatedAt"] as? String,
                  let rarity = BadgeRarity(rawValue: rarityStr),
                  let criteriaType = CriteriaType(rawValue: criteriaTypeStr) else {
                fetchError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid badge data"])
                group.leave()
                return
            }
            
            badge = Badge(
                id: badgeId,
                name: name,
                description: description,
                icon: icon,
                rarity: rarity,
                criteriaType: criteriaType,
                criteriaValue: criteriaValue,
                isSecret: isSecret,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
            
            group.leave()
        }
        
        // 2. Fetch User Badge
        group.enter()
        let userBadgeId = "\(userId)_\(badgeId)"
        db.collection("user_badges").document(userBadgeId).getDocument { snapshot, error in
            if let error = error {
                fetchError = error
                group.leave()
                return
            }
            
            guard let data = snapshot?.data(),
                  let userIdData = data["userId"] as? String,
                  let badgeIdData = data["badgeId"] as? String,
                  let progress = data["progress"] as? Int,
                  let isUnlocked = data["isUnlocked"] as? Bool else {
                fetchError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid user badge data"])
                group.leave()
                return
            }
            
            var earnedAt: Date?
            if let timestamp = data["earnedAt"] as? Timestamp {
                earnedAt = timestamp.dateValue()
            }
            
            userBadge = UserBadge(
                id: userBadgeId,
                userId: userIdData,
                badgeId: badgeIdData,
                progress: progress,
                isUnlocked: isUnlocked,
                earnedAt: earnedAt
            )
            
            group.leave()
        }
        
        // 3. Count total users with this badge (for stats)
        group.enter()
        db.collection("user_badges")
            .whereField("badgeId", isEqualTo: badgeId)
            .whereField("isUnlocked", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("⚠️ Error counting users with badge: \(error.localizedDescription)")
                } else {
                    totalUsersWithBadge = snapshot?.documents.count ?? 0
                }
                group.leave()
            }
        
        // 4. Count total users (for completion rate)
        group.enter()
        db.collection("user_badges")
            .whereField("badgeId", isEqualTo: badgeId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("⚠️ Error counting total users: \(error.localizedDescription)")
                } else {
                    totalUsers = snapshot?.documents.count ?? 0
                }
                group.leave()
            }
        
        // Wait for all requests
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
                return
            }
            
            guard let badge = badge, let userBadge = userBadge else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load badge data"])))
                return
            }
            
            let completionRate = totalUsers > 0 ? (totalUsersWithBadge * 100) / totalUsers : 0
            
            let detail = BadgeDetail(
                id: badgeId,
                badge: badge,
                userBadge: userBadge,
                totalUsersWithBadge: totalUsersWithBadge,
                completionRate: completionRate
            )
            
            print("✅ Network fetch completed for badge detail: \(badgeId)")
            completion(.success(detail))
        }
    }
}
