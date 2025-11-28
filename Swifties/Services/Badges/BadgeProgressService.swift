//
//  BadgeProgressService.swift
//  Swifties
//
//  Service to automatically update badge progress
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class BadgeProgressService {
    static let shared = BadgeProgressService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    // MARK: - Update Progress After Activity
    
    func updateProgressAfterActivity(userId: String, activityType: ActivityType) {
        print("🔄 Updating badge progress after activity: \(activityType)")
        
        // Fetch current user stats
        fetchUserStats(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let stats):
                print("📊 Current stats - Events: \(stats.eventsAttended), Activities: \(stats.activitiesCompleted), Categories: \(stats.categoriesCompleted)")
                
                // Update ALL relevant badges based on current stats
                self.updateAllBadges(userId: userId, stats: stats)
                
            case .failure(let error):
                print("❌ Error fetching user stats: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update All Badges
    
    private func updateAllBadges(userId: String, stats: UserStats) {
        // Fetch all badges definitions first
        db.collection("badges").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching badges: \(error.localizedDescription)")
                return
            }
            
            guard let badgeDocs = snapshot?.documents else {
                print("❌ No badges found")
                return
            }
            
            print("📋 Found \(badgeDocs.count) badges to check")
            
            let group = DispatchGroup()
            
            for badgeDoc in badgeDocs {
                let badgeId = badgeDoc.documentID
                let badgeData = badgeDoc.data()
                
                guard let criteriaTypeStr = badgeData["criteriaType"] as? String,
                      let criteriaType = CriteriaType(rawValue: criteriaTypeStr),
                      let criteriaValue = badgeData["criteriaValue"] as? Int else {
                    continue
                }
                
                // Calculate current progress for this badge
                let currentProgress: Int
                switch criteriaType {
                case .eventsAttended:
                    currentProgress = stats.eventsAttended
                case .activitiesCompleted:
                    currentProgress = stats.activitiesCompleted
         
                case .weeklyChallenges:
                    currentProgress = 0 // Not implemented yet
                }
                
                let isUnlocked = currentProgress >= criteriaValue
                
                // Update this specific user badge
                group.enter()
                self.updateUserBadge(
                    userId: userId,
                    badgeId: badgeId,
                    badgeName: badgeData["name"] as? String ?? badgeId,
                    progress: currentProgress,
                    isUnlocked: isUnlocked,
                    criteriaValue: criteriaValue
                ) {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                print("✅ Finished updating all badges")
                
                // Clear badge cache so next time it loads fresh data
                BadgeCacheService.shared.clearCache(userId: userId)
                BadgeStorageService.shared.deleteBadges(userId: userId)
            }
        }
    }
    
    // MARK: - Update Single User Badge
    
    private func updateUserBadge(userId: String, badgeId: String, badgeName: String, progress: Int, isUnlocked: Bool, criteriaValue: Int, completion: @escaping () -> Void) {
        let userBadgeId = "\(userId)_\(badgeId)"
        let userBadgeRef = db.collection("user_badges").document(userBadgeId)
        
        // First check if user badge exists
        userBadgeRef.getDocument { [weak self] snapshot, error in
            guard let self = self else {
                completion()
                return
            }
            
            let wasUnlocked = (snapshot?.data()?["isUnlocked"] as? Bool) ?? false
            
            var updateData: [String: Any] = [
                "userId": userId,
                "badgeId": badgeId,
                "progress": progress,
                "isUnlocked": isUnlocked
            ]
            
            // Set earnedAt if newly unlocked
            if isUnlocked && !wasUnlocked {
                updateData["earnedAt"] = Timestamp(date: Date())
                print("🎉 Badge unlocked: \(badgeName) (progress: \(progress)/\(criteriaValue))")
                
                // TODO: Show notification
                // BadgeNotificationService.shared.showUnlockedBadge(badge)
            } else if isUnlocked {
                print("✅ Badge already unlocked: \(badgeName)")
            } else {
                print("📊 Badge progress updated: \(badgeName) (\(progress)/\(criteriaValue))")
            }
            
            // If doesn't exist, we need to set the earnedAt to null explicitly
            if snapshot?.exists == false && !isUnlocked {
                updateData["earnedAt"] = NSNull()
            }
            
            // Update or create the user badge
            userBadgeRef.setData(updateData, merge: true) { error in
                if let error = error {
                    print("❌ Error updating badge \(badgeId): \(error.localizedDescription)")
                } else {
                    print("✅ Updated user badge: \(badgeId) - unlocked: \(isUnlocked), progress: \(progress)")
                }
                completion()
            }
        }
    }
    
    // MARK: - Fetch User Stats
    
    private func fetchUserStats(userId: String, completion: @escaping (Result<UserStats, Error>) -> Void) {
        let group = DispatchGroup()
        
        var eventsAttended = 0
        var activitiesCompleted = 0
        var categoriesCompleted: Set<String> = []
        var fetchError: Error?
        
        // Count activities from user_activities
        group.enter()
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    group.leave()
                    return
                }
                
                if let error = error {
                    fetchError = error
                    print("❌ Error fetching activities: \(error.localizedDescription)")
                } else if let documents = snapshot?.documents {
                    activitiesCompleted = documents.count
                    print("📊 Total activities: \(activitiesCompleted)")
                    
                    // Count events attended
                    eventsAttended = documents.filter {
                        let data = $0.data()
                        let source = data["source"] as? String
                        let type = data["type"] as? String
                        return source == "weekly_challenge" ||
                               source == "list_events" ||
                               type == "event" ||
                               type == "event_attendance" ||
                               type == "weekly_challenge"
                    }.count
                    print("📊 Events attended: \(eventsAttended)")
                    
                    // Extract unique event_ids to count categories
                    let eventIds = Set(documents.compactMap { $0.data()["event_id"] as? String })
                    print("📊 Unique event IDs: \(eventIds.count)")
                    
                    // Fetch events to get their categories
                    if !eventIds.isEmpty {
                        group.enter()
                        self.db.collection("events")
                            .whereField(FieldPath.documentID(), in: Array(eventIds))
                            .getDocuments { eventsSnapshot, eventsError in
                                if let eventsDocs = eventsSnapshot?.documents {
                                    categoriesCompleted = Set(eventsDocs.compactMap { $0.data()["category"] as? String })
                                    print("📊 Categories completed: \(categoriesCompleted.count) - \(categoriesCompleted)")
                                }
                                group.leave()
                            }
                    }
                }
                group.leave()
            }
        
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                let stats = UserStats(
                    eventsAttended: eventsAttended,
                    activitiesCompleted: activitiesCompleted,
                    categoriesCompleted: categoriesCompleted.count
                )
                print("📊 Final stats - Events: \(eventsAttended), Activities: \(activitiesCompleted), Categories: \(categoriesCompleted.count)")
                completion(.success(stats))
            }
        }
    }
}

// MARK: - Activity Type Enum

enum ActivityType {
    case weeklyChallenge
    case event
    case regularActivity
}
