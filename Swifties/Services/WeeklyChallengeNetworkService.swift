//
//  WeeklyChallengeNetworkService.swift
//  Swifties
//
//  Layer 3: Network Service for Weekly Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct WeeklyChallengeData {
    let event: Event?
    let hasAttended: Bool
    let totalChallenges: Int
    let chartData: [WeeklyChallengeChartData]
}

class WeeklyChallengeNetworkService {
    static let shared = WeeklyChallengeNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    // MARK: - Fetch Complete Challenge Data
    
    func fetchChallengeData(userId: String, completion: @escaping (Result<WeeklyChallengeData, Error>) -> Void) {
        print("🌐 Fetching challenge data from network...")
        
        let group = DispatchGroup()
        
        var fetchedEvent: Event?
        var fetchedHasAttended = false
        var fetchedTotalChallenges = 0
        var fetchedChartData: [WeeklyChallengeChartData] = []
        var fetchError: Error?
        
        // 1. Load Random Event
        group.enter()
        loadRandomEvent { result in
            switch result {
            case .success(let event):
                fetchedEvent = event
                
                // Check if attended
                group.enter()
                self.checkIfUserAttended(userId: userId, eventId: event.name) { attended in
                    fetchedHasAttended = attended
                    group.leave()
                }
                
            case .failure(let error):
                fetchError = error
            }
            group.leave()
        }
        
        // 2. Load Stats
        group.enter()
        loadUserChallengeStats(userId: userId) { result in
            switch result {
            case .success(let stats):
                fetchedTotalChallenges = stats
            case .failure(let error):
                print("⚠️ Error loading stats: \(error.localizedDescription)")
            }
            group.leave()
        }
        
        // 3. Load Chart Data
        group.enter()
        loadLast30DaysData(userId: userId) { result in
            switch result {
            case .success(let data):
                fetchedChartData = data
            case .failure(let error):
                print("⚠️ Error loading chart data: \(error.localizedDescription)")
            }
            group.leave()
        }
        
        // Notify when all done
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                let data = WeeklyChallengeData(
                    event: fetchedEvent,
                    hasAttended: fetchedHasAttended,
                    totalChallenges: fetchedTotalChallenges,
                    chartData: fetchedChartData
                )
                print("✅ Network fetch completed")
                completion(.success(data))
            }
        }
    }
    
    // MARK: - Mark as Attending
    
    func markAsAttending(userId: String, event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        let activityData: [String: Any] = [
            "event_id": event.name,
            "source": "weekly_challenge",
            "time": Timestamp(date: Date()),
            "time_of_day": getCurrentTimeOfDay(),
            "type": "weekly_challenge",
            "user_id": userId,
            "with_friends": false
        ]
        
        print("🔵 Saving activity to network...")
        
        db.collection("user_activities").addDocument(data: activityData) { error in
            if let error = error {
                print("❌ Error saving activity: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Activity saved to network")
                
                // Update user's last event
                self.updateUserLastEvent(userId: userId, event: event, completion: completion)
            }
        }
    }
    
    private func updateUserLastEvent(userId: String, event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "last_event": event.name,
            "last_event_time": Timestamp(date: Date()),
            "event_last_category": event.category
        ]) { error in
            if let error = error {
                print("❌ Error updating last_event: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ User's last_event updated")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func checkIfUserAttended(userId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("event_id", isEqualTo: eventId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error checking attendance: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                let attended = (snapshot?.documents.count ?? 0) > 0
                print(attended ? "✅ User attended" : "❌ User not attended")
                completion(attended)
            }
    }
    
    private func loadUserChallengeStats(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                completion(.success(count))
            }
    }
    
    private func loadLast30DaysData(userId: String, completion: @escaping (Result<[WeeklyChallengeChartData], Error>) -> Void) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        
        let currentDate = Date()
        
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                var activityDates: [Date] = []
                if let documents = snapshot?.documents {
                    for doc in documents {
                        if let timestamp = doc.data()["time"] as? Timestamp {
                            activityDates.append(timestamp.dateValue())
                        }
                    }
                }
                
                var chartData: [WeeklyChallengeChartData] = []
                
                for i in 0..<4 {
                    let weeksAgo = 3 - i
                    let targetDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentDate) ?? currentDate
                    
                    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
                        continue
                    }
                    
                    let activitiesInWeek = activityDates.filter { activityDate in
                        activityDate >= weekInterval.start && activityDate < weekInterval.end
                    }
                    
                    let label = weeksAgo == 0 ? "This Week" : "\(weeksAgo)w ago"
                    let hasCompleted = !activitiesInWeek.isEmpty
                    chartData.append(WeeklyChallengeChartData(label: label, count: hasCompleted ? 1 : 0))
                }
                
                completion(.success(chartData))
            }
    }
    
    private func loadRandomEvent(completion: @escaping (Result<Event, Error>) -> Void) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No events available"])
                completion(.failure(error))
                return
            }
            
            let seed = weekOfYear + (year * 100)
            let index = seed % documents.count
            let selectedDoc = documents[index]
            
            if let event = EventFactory.createEvent(from: selectedDoc) {
                completion(.success(event))
            } else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse event"])
                completion(.failure(error))
            }
        }
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}
