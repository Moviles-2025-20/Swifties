//
//  BadgeNetworkService.swift
//  Swifties
//
//  Layer 3: Network Service for Badges
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class BadgeNetworkService {
    static let shared = BadgeNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Fetch Badges and User Progress
    
    func fetchBadgesData(userId: String, completion: @escaping (Result<(badges: [Badge], userBadges: [UserBadge]), Error>) -> Void) {
        print("🌐 Fetching badges data from network...")
        
        let group = DispatchGroup()
        
        var fetchedBadges: [Badge] = []
        var fetchedUserBadges: [UserBadge] = []
        var fetchError: Error?
        
        // 1. Fetch all badges
        group.enter()
        db.collection("badges").getDocuments { snapshot, error in
            if let error = error {
                fetchError = error
                group.leave()
                return
            }
            
            guard let documents = snapshot?.documents else {
                group.leave()
                return
            }
            
            fetchedBadges = documents.compactMap { doc -> Badge? in
                let data = doc.data()
                
                guard let name = data["name"] as? String,
                      let description = data["description"] as? String,
                      let icon = data["icon"] as? String,
                      let rarityStr = data["rarity"] as? String,
                      let criteriaTypeStr = data["criteriaType"] as? String,
                      let criteriaValue = data["criteriaValue"] as? Int,
                      let isSecret = data["isSecret"] as? Bool,
                      let createdAt = data["createdAt"] as? String,
                      let updatedAt = data["updatedAt"] as? String else {
                    return nil
                }
                
                guard let rarity = BadgeRarity(rawValue: rarityStr),
                      let criteriaType = CriteriaType(rawValue: criteriaTypeStr) else {
                    return nil
                }
                
                return Badge(
                    id: doc.documentID,
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
            }
            
            print("✅ Fetched \(fetchedBadges.count) badges")
            group.leave()
        }
        
        // 2. Fetch user badges (or initialize if not exists)
        group.enter()
        db.collection("user_badges")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("⚠️ Error fetching user badges: \(error.localizedDescription)")
                    group.leave()
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    // User badges exist
                    fetchedUserBadges = documents.compactMap { doc -> UserBadge? in
                        let data = doc.data()
                        
                        guard let userId = data["userId"] as? String,
                              let badgeId = data["badgeId"] as? String,
                              let progress = data["progress"] as? Int,
                              let isUnlocked = data["isUnlocked"] as? Bool else {
                            return nil
                        }
                        
                        var earnedAt: Date?
                        if let timestamp = data["earnedAt"] as? Timestamp {
                            earnedAt = timestamp.dateValue()
                        }
                        
                        return UserBadge(
                            id: doc.documentID,
                            userId: userId,
                            badgeId: badgeId,
                            progress: progress,
                            isUnlocked: isUnlocked,
                            earnedAt: earnedAt
                        )
                    }
                    print("✅ Fetched \(fetchedUserBadges.count) user badges")
                    group.leave()
                } else {
                    // Initialize user badges for first time
                    print("🔵 No user badges found, initializing...")
                    self.initializeUserBadges(userId: userId) { result in
                        switch result {
                        case .success(let userBadges):
                            fetchedUserBadges = userBadges
                        case .failure(let error):
                            fetchError = error
                        }
                        group.leave()
                    }
                }
            }
        
        // Notify when all done
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                print("✅ Network fetch completed: \(fetchedBadges.count) badges, \(fetchedUserBadges.count) user badges")
                completion(.success((badges: fetchedBadges, userBadges: fetchedUserBadges)))
            }
        }
    }
    
    // MARK: - Initialize User Badges
    
    private func initializeUserBadges(userId: String, completion: @escaping (Result<[UserBadge], Error>) -> Void) {
        // First, fetch all badges
        db.collection("badges").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            // Then fetch user stats to calculate initial progress
            self.fetchUserStats(userId: userId) { statsResult in
                switch statsResult {
                case .success(let stats):
                    var userBadges: [UserBadge] = []
                    let group = DispatchGroup()
                    var initError: Error?
                    
                    for doc in documents {
                        group.enter()
                        let badgeId = doc.documentID
                        let data = doc.data()
                        
                        guard let criteriaTypeStr = data["criteriaType"] as? String,
                              let criteriaValue = data["criteriaValue"] as? Int,
                              let criteriaType = CriteriaType(rawValue: criteriaTypeStr) else {
                            group.leave()
                            continue
                        }
                        
                        // Calculate initial progress based on user stats
                        let progress = self.calculateProgress(criteriaType: criteriaType, stats: stats)
                        let isUnlocked = progress >= criteriaValue
                        
                        let userBadgeId = "\(userId)_\(badgeId)"
                        let userBadgeData: [String: Any] = [
                            "userId": userId,
                            "badgeId": badgeId,
                            "progress": progress,
                            "isUnlocked": isUnlocked,
                            "earnedAt": isUnlocked ? Timestamp(date: Date()) : NSNull()
                        ]
                        
                        self.db.collection("user_badges").document(userBadgeId).setData(userBadgeData) { error in
                            if let error = error {
                                initError = error
                            } else {
                                let userBadge = UserBadge(
                                    id: userBadgeId,
                                    userId: userId,
                                    badgeId: badgeId,
                                    progress: progress,
                                    isUnlocked: isUnlocked,
                                    earnedAt: isUnlocked ? Date() : nil
                                )
                                userBadges.append(userBadge)
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        if let error = initError {
                            completion(.failure(error))
                        } else {
                            print("✅ Initialized \(userBadges.count) user badges")
                            completion(.success(userBadges))
                        }
                    }
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch User Stats for Badge Progress
    
    private func fetchUserStats(userId: String, completion: @escaping (Result<UserStats, Error>) -> Void) {
        let group = DispatchGroup()
        
        var eventsAttended = 0
        var activitiesCompleted = 0
        
        // 🆕 Nuevas variables
        var morningActivities = 0
        var afternoonActivities = 0
        var eveningActivities = 0
        var nightActivities = 0
        var timeSlots = Set<String>()
        var commentsLeft = 0
        var weeklyChallengesCompleted = 0
        
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
                        return source == "weekly_challenge" || type == "event"
                    }.count
                    
                    // 🆕 Count activities by time of day
                    for doc in documents {
                        let data = doc.data()
                        
                        // Count time slots
                        if let timeOfDay = data["time_of_day"] as? String {
                            timeSlots.insert(timeOfDay)
                            
                            switch timeOfDay {
                            case "morning":
                                morningActivities += 1
                            case "afternoon":
                                afternoonActivities += 1
                            case "evening":
                                eveningActivities += 1
                            case "night":
                                nightActivities += 1
                            default:
                                break
                            }
                        }
                        
                        // Count comments
                        if data["comment_id"] != nil && !(data["comment_id"] is NSNull) {
                            commentsLeft += 1
                        }
                        
                        // Count weekly challenges
                        let source = data["source"] as? String
                        let type = data["type"] as? String
                        if source == "weekly_challenge" || type == "weekly_challenge" {
                            weeklyChallengesCompleted += 1
                        }
                    }
                }
                group.leave()
            }
        
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                // Check if user has activities in all time slots
                let hasAllTimeSlots = timeSlots.contains("morning") &&
                                      timeSlots.contains("afternoon") &&
                                      timeSlots.contains("evening") &&
                                      timeSlots.contains("night")
                
                let stats = UserStats(
                    eventsAttended: eventsAttended,
                    activitiesCompleted: activitiesCompleted,
                    morningActivities: morningActivities,
                    afternoonActivities: afternoonActivities,
                    eveningActivities: eveningActivities,
                    nightActivities: nightActivities,
                    hasAllTimeSlots: hasAllTimeSlots,
                    commentsLeft: commentsLeft,
                    weeklyChallengesCompleted: weeklyChallengesCompleted
                )
                completion(.success(stats))
            }
        }
    }
    
    // MARK: - Calculate Progress
    
    private func calculateProgress(criteriaType: CriteriaType, stats: UserStats) -> Int {
        switch criteriaType {
        case .eventsAttended:
            return stats.eventsAttended
        case .activitiesCompleted:
            return stats.activitiesCompleted
        case .weeklyChallenges:
            return stats.weeklyChallengesCompleted
            
        // 🆕 Nuevos casos
        case .morningActivities:
            return stats.morningActivities
        case .nightActivities:
            return stats.nightActivities
        case .allDayWarrior:
            return stats.hasAllTimeSlots ? 1 : 0
        case .firstComment:
            return stats.commentsLeft > 0 ? 1 : 0
        case .commentsLeft:
            return stats.commentsLeft
        case .firstWeeklyChallenge:
            return stats.weeklyChallengesCompleted > 0 ? 1 : 0
        }
    }
    
    // MARK: - Update Badge Progress
    
    func updateBadgeProgress(userId: String, criteriaType: CriteriaType, newValue: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("user_badges")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success(()))
                    return
                }
                
                let batch = self.db.batch()
                
                for doc in documents {
                    let userBadgeRef = self.db.collection("user_badges").document(doc.documentID)
                    let badgeId = doc.data()["badgeId"] as? String ?? ""
                    
                    // Fetch the badge to check criteriaType
                    self.db.collection("badges").document(badgeId).getDocument { badgeDoc, error in
                        guard let badgeData = badgeDoc?.data(),
                              let badgeCriteriaTypeStr = badgeData["criteriaType"] as? String,
                              let badgeCriteriaType = CriteriaType(rawValue: badgeCriteriaTypeStr),
                              badgeCriteriaType == criteriaType,
                              let criteriaValue = badgeData["criteriaValue"] as? Int else {
                            return
                        }
                        
                        let isUnlocked = newValue >= criteriaValue
                        var updateData: [String: Any] = [
                            "progress": newValue,
                            "isUnlocked": isUnlocked
                        ]
                        
                        if isUnlocked && doc.data()["earnedAt"] == nil {
                            updateData["earnedAt"] = Timestamp(date: Date())
                        }
                        
                        batch.updateData(updateData, forDocument: userBadgeRef)
                    }
                }
                
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        print("✅ Badge progress updated")
                        completion(.success(()))
                    }
                }
            }
    }
    
    // MARK: - Resolve Badge Icon URL
    
    func resolveBadgeIconURL(iconPath: String, completion: @escaping (String?) -> Void) {
        let ref = storage.reference(withPath: iconPath)
        ref.downloadURL { url, error in
            if let error = error {
                print("⚠️ Error resolving badge icon: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(url?.absoluteString)
            }
        }
    }
}
