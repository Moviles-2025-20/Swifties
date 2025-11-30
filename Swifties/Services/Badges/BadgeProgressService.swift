//
//  BadgeProgressService.swift
//  Swifties
//
//  Service con Estrategias de Multithreading Distribuidas
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class BadgeProgressService {
    static let shared = BadgeProgressService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    // MARK: - UPDATE PROGRESS AFTER ACTIVITY (Usa ESTRATEGIA 1: Dispatcher - 5 puntos)
    // Entry point usa dispatcher simple para iniciar el proceso
    
    func updateProgressAfterActivity(userId: String, activityType: ActivityType) {
        print("🔄 [DISPATCHER] Updating badge progress after activity: \(activityType)")
        
        // Queue de alta prioridad para operaciones críticas
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🧵 [DISPATCHER] Fetching user stats...")
            
            Task {
                let stats = await withCheckedContinuation { continuation in
                    self.fetchUserStats(userId: userId) { result in
                        continuation.resume(returning: result)
                    }
                }
                
                switch stats {
                case .success(let userStats):
                    // Una vez que tenemos stats, usar estrategia más avanzada
                    await self.updateAllBadgesWithNestedTasks(userId: userId, stats: userStats)
                case .failure(let error):
                    print("❌ Error fetching user stats: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - UPDATE ALL BADGES (Usa ESTRATEGIA 2: Nested Coroutines - 10 puntos)
    // Actualizar todos los badges usa corrutinas anidadas
    
    private func updateAllBadgesWithNestedTasks(userId: String, stats: UserStats) async {
        print("🔄 [NESTED] Starting nested badge updates...")
        
        // NIVEL 1: Fetch all badges en background
        let badges = await Task.detached(priority: .userInitiated) { [weak self] () -> [DocumentSnapshot]? in
            guard let self = self else { return nil }
            print("🧵 [NIVEL 1 - I/O] Fetching badges from Firestore...")
            
            return await withCheckedContinuation { continuation in
                self.db.collection("badges").getDocuments { snapshot, error in
                    continuation.resume(returning: snapshot?.documents)
                }
            }
        }.value
        
        guard let validBadges = badges else {
            print("❌ Failed to fetch badges")
            return
        }
        
        print("📋 Found \(validBadges.count) badges to process")
        
        // NIVEL 2: Process each badge con tasks anidados paralelos
        await withTaskGroup(of: Void.self) { group in
            for badgeDoc in validBadges {
                group.addTask(priority: .utility) {
                    await self.processSingleBadgeNested(
                        userId: userId,
                        badgeDoc: badgeDoc,
                        stats: stats
                    )
                }
            }
        }
        
        // NIVEL 3: Clear cache en main thread
        await MainActor.run {
            print("✅ [MAIN] All badges processed, clearing cache...")
            BadgeCacheService.shared.clearCache(userId: userId)
            BadgeStorageService.shared.deleteBadges(userId: userId)
        }
    }
    
    private func processSingleBadgeNested(userId: String, badgeDoc: DocumentSnapshot, stats: UserStats) async {
        let badgeId = badgeDoc.documentID
        let badgeData = badgeDoc.data() ?? [:]
        
        // Nested task para calcular progress en background
        let progress = await Task.detached(priority: .utility) { () -> (progress: Int, isUnlocked: Bool)? in
            guard let criteriaTypeStr = badgeData["criteriaType"] as? String,
                  let criteriaType = CriteriaType(rawValue: criteriaTypeStr),
                  let criteriaValue = badgeData["criteriaValue"] as? Int else {
                return nil
            }
            
            let currentProgress = self.calculateProgress(criteriaType: criteriaType, stats: stats)
            let isUnlocked = currentProgress >= criteriaValue
            
            return (currentProgress, isUnlocked)
        }.value
        
        guard let validProgress = progress else { return }
        
        // Nested task para actualizar en Firestore
        await updateUserBadgeAsync(
            userId: userId,
            badgeId: badgeId,
            badgeName: badgeData["name"] as? String ?? badgeId,
            progress: validProgress.progress,
            isUnlocked: validProgress.isUnlocked,
            criteriaValue: badgeData["criteriaValue"] as? Int ?? 0
        )
    }
    
    // MARK: - FETCH USER STATS (Usa ESTRATEGIA 3: I/O + Main - 10 puntos)
    // Fetch stats usa I/O background + Main thread pattern
    
    private func fetchUserStats(userId: String, completion: @escaping (Result<UserStats, Error>) -> Void) {
        // FASE I/O: Fetch en background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(.failure(NSError(domain: "BadgeProgressService", code: -1)))
                return
            }
            
            print("🧵 [I/O THREAD] Fetching user activities from Firestore...")
            
            let group = DispatchGroup()
            
            var eventsAttended = 0
            var activitiesCompleted = 0
            var morningActivities = 0
            var afternoonActivities = 0
            var eveningActivities = 0
            var nightActivities = 0
            var timeSlots = Set<String>()
            var commentsLeft = 0
            var weeklyChallengesCompleted = 0
            
            var fetchError: Error?
            
            group.enter()
            self.db.collection("user_activities")
                .whereField("user_id", isEqualTo: userId)
                .getDocuments { snapshot, error in
                    if let error = error {
                        fetchError = error
                    } else if let documents = snapshot?.documents {
                        activitiesCompleted = documents.count
                        
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
                        
                        for doc in documents {
                            let data = doc.data()
                            
                            if let timeOfDay = data["time_of_day"] as? String {
                                timeSlots.insert(timeOfDay)
                                
                                switch timeOfDay {
                                case "morning": morningActivities += 1
                                case "afternoon": afternoonActivities += 1
                                case "evening": eveningActivities += 1
                                case "night": nightActivities += 1
                                default: break
                                }
                            }
                            
                            if data["comment_id"] != nil && !(data["comment_id"] is NSNull) {
                                commentsLeft += 1
                            }
                            
                            let source = data["source"] as? String
                            let type = data["type"] as? String
                            if source == "weekly_challenge" || type == "weekly_challenge" {
                                weeklyChallengesCompleted += 1
                            }
                        }
                        
                        print("✅ [I/O] Fetched \(activitiesCompleted) activities")
                    }
                    group.leave()
                }
            
            // FASE MAIN: Return to main thread
            group.notify(queue: .main) {
                print("🧵 [MAIN THREAD] Processing stats results...")
                
                if let error = fetchError {
                    completion(.failure(error))
                } else {
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
                    
                    print("✅ [MAIN] Stats calculated successfully")
                    completion(.success(stats))
                }
            }
        }
    }
    
    // MARK: - UPDATE USER BADGE (Usa ESTRATEGIA 4: Parallel Tasks - 10 puntos)
    // Actualizar badge individual usa tasks paralelos para optimizar
    
    private func updateUserBadgeAsync(userId: String, badgeId: String, badgeName: String, progress: Int, isUnlocked: Bool, criteriaValue: Int) async {
        let userBadgeId = "\(userId)_\(badgeId)"
        let userBadgeRef = db.collection("user_badges").document(userBadgeId)
        
        print("🔄 [PARALLEL] Updating badge \(badgeId)...")
        
        // Task paralelos: fetch actual state y prepare update data simultáneamente
        async let fetchTask = Task.detached(priority: .userInitiated) { () -> Bool in
            print("🧵 [TASK 1] Fetching current badge state...")
            
            let snapshot: DocumentSnapshot? = await withCheckedContinuation { continuation in
                userBadgeRef.getDocument { snapshot, error in
                    continuation.resume(returning: snapshot)
                }
            }
            
            return (snapshot?.data()?["isUnlocked"] as? Bool) ?? false
        }.value
        
        async let prepareTask = Task.detached(priority: .utility) { () -> [String: Any] in
            print("🧵 [TASK 2] Preparing update data...")
            var updateData: [String: Any] = [
                "userId": userId,
                "badgeId": badgeId,
                "progress": progress,
                "isUnlocked": isUnlocked
            ]
            return updateData
        }.value
        
        // Esperar ambos tasks
        let (wasUnlocked, baseData) = await (fetchTask, prepareTask)
        var updateData = baseData
        
        // Determinar si es nuevo unlock
        if isUnlocked && !wasUnlocked {
            updateData["earnedAt"] = Timestamp(date: Date())
            print("🎉 Badge unlocked: \(badgeName) (\(progress)/\(criteriaValue))")
        } else if isUnlocked {
            print("✅ Badge already unlocked: \(badgeName)")
        } else {
            updateData["earnedAt"] = NSNull()
            print("📊 Badge progress: \(badgeName) (\(progress)/\(criteriaValue))")
        }
        
        // Update en Firestore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            userBadgeRef.setData(updateData, merge: true) { error in
                if let error = error {
                    print("❌ Error updating badge: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - CALCULATE PROGRESS (Simple sync function)
    
    private func calculateProgress(criteriaType: CriteriaType, stats: UserStats) -> Int {
        switch criteriaType {
        case .eventsAttended:
            return stats.eventsAttended
        case .activitiesCompleted:
            return stats.activitiesCompleted
        case .weeklyChallenges:
            return stats.weeklyChallengesCompleted
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
}

// MARK: - Supporting Types

struct BadgeUpdateResult {
    let badgeId: String
    let success: Bool
    let progress: Int
    let unlocked: Bool
}

// MARK: - Activity Type Enum

enum ActivityType {
    case weeklyChallenge
    case event
    case regularActivity
}
