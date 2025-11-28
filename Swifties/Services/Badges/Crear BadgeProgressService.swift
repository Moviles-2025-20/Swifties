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
    private let networkService = BadgeNetworkService.shared
    
    private init() {}
    
    // MARK: - Update Progress After Activity
    
    func updateProgressAfterActivity(userId: String, activityType: ActivityType) {
        print("🔄 Updating badge progress after activity: \(activityType)")
        
        // Fetch current user stats
        fetchUserStats(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let stats):
                // Update badges based on activity type
                switch activityType {
                case .weeklyChallenge, .event:
                    self.updateBadgesByCriteria(userId: userId, criteriaType: .eventsAttended, newValue: stats.eventsAttended)
                    
                case .regularActivity:
                    self.updateBadgesByCriteria(userId: userId, criteriaType: .activitiesCompleted, newValue: stats.activitiesCompleted)
                }
                
                // Always check categories completed
                self.updateBadgesByCriteria(userId: userId, criteriaType: .categoriesCompleted, newValue: stats.categoriesCompleted)
                
            case .failure(let error):
                print("❌ Error fetching user stats: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update Badges by Criteria
    
    private func updateBadgesByCriteria(userId: String, criteriaType: CriteriaType, newValue: Int) {
        print("🔄 Updating badges for \(criteriaType.displayName): \(newValue)")
        
        // Get all user badges
        db.collection("user_badges")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user badges: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let group = DispatchGroup()
                
                for userBadgeDoc in documents {
                    let userBadgeId = userBadgeDoc.documentID
                    let badgeId = userBadgeDoc.data()["badgeId"] as? String ?? ""
                    
                    // Fetch the badge definition
                    group.enter()
                    self.db.collection("badges").document(badgeId).getDocument { badgeDoc, error in
                        defer { group.leave() }
                        
                        guard let badgeData = badgeDoc?.data(),
                              let badgeCriteriaTypeStr = badgeData["criteriaType"] as? String,
                              let badgeCriteriaType = CriteriaType(rawValue: badgeCriteriaTypeStr),
                              badgeCriteriaType == criteriaType,
                              let criteriaValue = badgeData["criteriaValue"] as? Int else {
                            return
                        }
                        
                        // Calculate if badge should be unlocked
                        let isUnlocked = newValue >= criteriaValue
                        let wasUnlocked = userBadgeDoc.data()["isUnlocked"] as? Bool ?? false
                        
                        var updateData: [String: Any] = [
                            "progress": newValue,
                            "isUnlocked": isUnlocked
                        ]
                        
                        // Set earnedAt if newly unlocked
                        if isUnlocked && !wasUnlocked {
                            updateData["earnedAt"] = Timestamp(date: Date())
                            print("🎉 Badge unlocked: \(badgeData["name"] as? String ?? badgeId)")
                        }
                        
                        // Update the user badge
                        self.db.collection("user_badges").document(userBadgeId).updateData(updateData) { error in
                            if let error = error {
                                print("❌ Error updating badge \(badgeId): \(error.localizedDescription)")
                            } else {
                                print("✅ Updated badge \(badgeId): progress=\(newValue), unlocked=\(isUnlocked)")
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("✅ Finished updating badges for \(criteriaType.displayName)")
                    
                    // Clear badge cache so next time it loads fresh data
                    BadgeCacheService.shared.clearCache(userId: userId)
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
        
        // Count activities
        group.enter()
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    fetchError = error
                } else if let documents = snapshot?.documents {
                    activitiesCompleted = documents.count
                    
                    // Count events attended (source = weekly_challenge or type = event)
                    eventsAttended = documents.filter {
                        let data = $0.data()
                        let source = data["source"] as? String
                        let type = data["type"] as? String
                        return source == "weekly_challenge" || type == "event" || type == "weekly_challenge"
                    }.count
                    
                    // Extract unique event_ids to count categories
                    let eventIds = Set(documents.compactMap { $0.data()["event_id"] as? String })
                    
                    // Fetch events to get their categories
                    if !eventIds.isEmpty {
                        group.enter()
                        self.db.collection("events")
                            .whereField(FieldPath.documentID(), in: Array(eventIds))
                            .getDocuments { eventsSnapshot, eventsError in
                                if let eventsDocs = eventsSnapshot?.documents {
                                    categoriesCompleted = Set(eventsDocs.compactMap { $0.data()["category"] as? String })
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
                print("📊 User stats: events=\(eventsAttended), activities=\(activitiesCompleted), categories=\(categoriesCompleted.count)")
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
