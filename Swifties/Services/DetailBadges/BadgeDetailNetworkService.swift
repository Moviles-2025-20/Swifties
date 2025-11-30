//
//  BadgeDetailNetworkService.swift
//  Swifties
//
//  Layer 3: Network Service for Badge Detail with ESTRATEGIA 4: Parallel Tasks
//

import Foundation
import FirebaseFirestore

class BadgeDetailNetworkService {
    static let shared = BadgeDetailNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    // MARK: - Fetch Badge Detail (Usa ESTRATEGIA 4: Parallel Tasks - 10 puntos)
    // Fetch usa tasks paralelos para optimizar múltiples requests
    
    func fetchBadgeDetail(badgeId: String, userId: String, completion: @escaping (Result<BadgeDetail, Error>) -> Void) {
        print("🌐 [PARALLEL] Fetching badge detail from network: \(badgeId)")
        
        Task.detached(priority: .userInitiated) {
            // Ejecutar 4 requests en paralelo
            async let badgeTask = self.fetchBadgeAsync(badgeId: badgeId)
            async let userBadgeTask = self.fetchUserBadgeAsync(badgeId: badgeId, userId: userId)
            async let usersWithBadgeTask = self.countUsersWithBadgeAsync(badgeId: badgeId)
            async let totalUsersTask = self.countTotalUsersAsync(badgeId: badgeId)
            
            print("🔄 [PARALLEL] Waiting for all tasks to complete...")
            
            // Esperar todos los resultados en paralelo
            let results = await (badgeTask, userBadgeTask, usersWithBadgeTask, totalUsersTask)
            
            print("✅ [PARALLEL] All tasks completed:")
            print("   - Badge: \(results.0 != nil ? "✓" : "✗")")
            print("   - UserBadge: \(results.1 != nil ? "✓" : "✗")")
            print("   - UsersWithBadge: \(results.2)")
            print("   - TotalUsers: \(results.3)")
            
            // Procesar resultados en main thread
            await MainActor.run {
                guard let badge = results.0, let userBadge = results.1 else {
                    completion(.failure(NSError(
                        domain: "",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load badge data"]
                    )))
                    return
                }
                
                let totalUsersWithBadge = results.2
                let totalUsers = results.3
                let completionRate = totalUsers > 0 ? (totalUsersWithBadge * 100) / totalUsers : 0
                
                let detail = BadgeDetail(
                    id: badgeId,
                    badge: badge,
                    userBadge: userBadge,
                    totalUsersWithBadge: totalUsersWithBadge,
                    completionRate: completionRate
                )
                
                print("✅ [MAIN] Network fetch completed for badge detail: \(badgeId)")
                completion(.success(detail))
            }
        }
    }
    
    // MARK: - Individual Async Fetchers
    
    private func fetchBadgeAsync(badgeId: String) async -> Badge? {
        return await withCheckedContinuation { continuation in
            print("🧵 [TASK 1] Fetching badge...")
            
            db.collection("badges").document(badgeId).getDocument { snapshot, error in
                if let error = error {
                    print("❌ [TASK 1] Error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
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
                    continuation.resume(returning: nil)
                    return
                }
                
                let badge = Badge(
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
                
                print("✅ [TASK 1] Badge fetched")
                continuation.resume(returning: badge)
            }
        }
    }
    
    private func fetchUserBadgeAsync(badgeId: String, userId: String) async -> UserBadge? {
        return await withCheckedContinuation { continuation in
            print("🧵 [TASK 2] Fetching user badge...")
            
            let userBadgeId = "\(userId)_\(badgeId)"
            db.collection("user_badges").document(userBadgeId).getDocument { snapshot, error in
                if let error = error {
                    print("❌ [TASK 2] Error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let data = snapshot?.data(),
                      let userIdData = data["userId"] as? String,
                      let badgeIdData = data["badgeId"] as? String,
                      let progress = data["progress"] as? Int,
                      let isUnlocked = data["isUnlocked"] as? Bool else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var earnedAt: Date?
                if let timestamp = data["earnedAt"] as? Timestamp {
                    earnedAt = timestamp.dateValue()
                }
                
                let userBadge = UserBadge(
                    id: userBadgeId,
                    userId: userIdData,
                    badgeId: badgeIdData,
                    progress: progress,
                    isUnlocked: isUnlocked,
                    earnedAt: earnedAt
                )
                
                print("✅ [TASK 2] User badge fetched")
                continuation.resume(returning: userBadge)
            }
        }
    }
    
    private func countUsersWithBadgeAsync(badgeId: String) async -> Int {
        return await withCheckedContinuation { continuation in
            print("🧵 [TASK 3] Counting users with badge...")
            
            db.collection("user_badges")
                .whereField("badgeId", isEqualTo: badgeId)
                .whereField("isUnlocked", isEqualTo: true)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("⚠️ [TASK 3] Error: \(error.localizedDescription)")
                        continuation.resume(returning: 0)
                    } else {
                        let count = snapshot?.documents.count ?? 0
                        print("✅ [TASK 3] Counted \(count) users")
                        continuation.resume(returning: count)
                    }
                }
        }
    }
    
    private func countTotalUsersAsync(badgeId: String) async -> Int {
        return await withCheckedContinuation { continuation in
            print("🧵 [TASK 4] Counting total users...")
            
            db.collection("user_badges")
                .whereField("badgeId", isEqualTo: badgeId)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("⚠️ [TASK 4] Error: \(error.localizedDescription)")
                        continuation.resume(returning: 0)
                    } else {
                        let count = snapshot?.documents.count ?? 0
                        print("✅ [TASK 4] Counted \(count) total users")
                        continuation.resume(returning: count)
                    }
                }
        }
    }
    
    // MARK: - Batch Fetch (Usa ESTRATEGIA 5: TaskGroup - 10 puntos)
    // Fetch múltiples badges usa TaskGroup
    
    func fetchMultipleBadgeDetails(
        badgeIds: [(badgeId: String, userId: String)],
        completion: @escaping (Result<[BadgeDetail], Error>) -> Void
    ) {
        print("🔄 [TASKGROUP] Fetching multiple badge details...")
        
        Task.detached(priority: .userInitiated) {
            let details = await withTaskGroup(of: BadgeDetail?.self) { group -> [BadgeDetail] in
                
                for item in badgeIds {
                    group.addTask(priority: .userInitiated) { [weak self] in
                        guard let self = self else { return nil }
                        
                        print("🧵 [GROUP] Processing badge: \(item.badgeId)")
                        
                        // Fetch en paralelo dentro del grupo
                        async let badge = self.fetchBadgeAsync(badgeId: item.badgeId)
                        async let userBadge = self.fetchUserBadgeAsync(badgeId: item.badgeId, userId: item.userId)
                        async let usersWithBadge = self.countUsersWithBadgeAsync(badgeId: item.badgeId)
                        async let totalUsers = self.countTotalUsersAsync(badgeId: item.badgeId)
                        
                        let results = await (badge, userBadge, usersWithBadge, totalUsers)
                        
                        guard let fetchedBadge = results.0, let fetchedUserBadge = results.1 else {
                            return nil
                        }
                        
                        let completionRate = results.3 > 0 ? (results.2 * 100) / results.3 : 0
                        
                        return BadgeDetail(
                            id: item.badgeId,
                            badge: fetchedBadge,
                            userBadge: fetchedUserBadge,
                            totalUsersWithBadge: results.2,
                            completionRate: completionRate
                        )
                    }
                }
                
                // Recolectar resultados
                var allDetails: [BadgeDetail] = []
                for await detail in group {
                    if let detail = detail {
                        allDetails.append(detail)
                    }
                }
                
                print("✅ [TASKGROUP] Fetched \(allDetails.count) badge details")
                return allDetails
            }
            
            await MainActor.run {
                completion(.success(details))
            }
        }
    }
}
