//
//  WeeklyChallengeViewModel.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class WeeklyChallengeViewModel: ObservableObject {
    @Published var challengeEvent: Event?
    @Published var totalChallenges: Int = 0
    @Published var last30DaysData: [WeeklyChallengeChartData] = []
    @Published var hasAttended: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore(database: "default")
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    func loadChallenge() {
        isLoading = true
        errorMessage = nil
        hasAttended = false
        
        guard let userId = currentUserId else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }
        
        print("🚀 Loading challenge for user: \(userId)")
        
        let group = DispatchGroup()
        
        group.enter()
        loadRandomEvent { result in
            switch result {
            case .success(let event):
                DispatchQueue.main.async {
                    self.challengeEvent = event
                    print("✅ Event loaded: \(event.name)")
                }
                group.enter()
                self.checkIfUserAttended(userId: userId, eventId: event.name) {
                    group.leave()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
            group.leave()
        }
        
        group.enter()
        loadUserChallengeStats(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stats):
                    self.totalChallenges = stats
                case .failure(let error):
                    print("Error loading stats: \(error)")
                    self.totalChallenges = 0
                }
            }
            group.leave()
        }
        
        group.enter()
        loadLast30DaysData(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.last30DaysData = data
                case .failure(let error):
                    print("Error loading chart data: \(error)")
                    self.last30DaysData = []
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
            print("✅ Challenge loading completed. hasAttended: \(self.hasAttended)")
        }
    }
    
    func markAsAttending() {
        guard let userId = currentUserId,
              let event = challengeEvent else {
            print("Error: No user or event available")
            return
        }
        
        print("🔵 Saving activity for user: \(userId), event: \(event.name)")
        
        let activityData: [String: Any] = [
            "event_id": event.name,
            "source": "weekly_challenge",
            "time": Timestamp(date: Date()),
            "time_of_day": getCurrentTimeOfDay(),
            "type": "weekly_challenge",
            "user_id": userId,
            "with_friends": false
        ]
        
        print("🔵 Activity data: \(activityData)")
        
        db.collection("user_activities").addDocument(data: activityData) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error saving activity: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error saving activity: \(error.localizedDescription)"
                }
            } else {
                print("✅ Activity saved successfully!")
                self.updateUserLastEvent(userId: userId, eventName: event.name)
            }
        }
    }

    private func updateUserLastEvent(userId: String, eventName: String) {
        let userRef = db.collection("users").document(userId)
        
        guard let event = challengeEvent else {
            print("❌ Error: No event available")
            return
        }
        
        userRef.updateData([
            "last_event": eventName,
            "last_event_time": Timestamp(date: Date()),
            "event_last_category": event.category
        ]) { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error updating last_event: \(error.localizedDescription)")
                    self.errorMessage = "Error updating user profile: \(error.localizedDescription)"
                } else {
                    print("✅ User's last_event updated to: \(eventName), category: \(event.category)")
                    self.hasAttended = true
                    self.totalChallenges += 1
                    self.loadChallenge()
                }
            }
        }
    }
    
    private func checkIfUserAttended(userId: String, eventId: String, completion: @escaping () -> Void) {
        print("🔍 Checking attendance for user: \(userId), event: \(eventId)")
        
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("event_id", isEqualTo: eventId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    completion()
                    return
                }
                
                if let error = error {
                    print("❌ Error checking attendance: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.hasAttended = false
                    }
                    completion()
                    return
                }
                
                let documentsCount = snapshot?.documents.count ?? 0
                let attended = documentsCount > 0
                
                print("📊 Documents found for this event: \(documentsCount)")
                print(attended ? "✅ User HAS attended this event" : "❌ User has NOT attended this event")
                
                DispatchQueue.main.async {
                    self.hasAttended = attended
                    print("🔄 Updated hasAttended to: \(self.hasAttended)")
                }
                completion()
            }
    }
    
    private func loadUserChallengeStats(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        print("📊 Loading user challenge stats for: \(userId)")
        
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading stats: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("✅ Total challenges found: \(count)")
                completion(.success(count))
            }
    }
    
    private func loadLast30DaysData(userId: String, completion: @escaping (Result<[WeeklyChallengeChartData], Error>) -> Void) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        
        let currentDate = Date()
        
        guard calendar.date(byAdding: .day, value: -30, to: currentDate) != nil else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error calculating date"])
            completion(.failure(error))
            return
        }
        
        print("📊 Loading activities from last 30 days")
        
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error loading activities: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy HH:mm"
                dateFormatter.timeZone = calendar.timeZone
                
                var activityDates: [Date] = []
                if let documents = snapshot?.documents {
                    print("📄 Found \(documents.count) total activities in last 30 days:")
                    for doc in documents {
                        let data = doc.data()
                        if let timestamp = data["time"] as? Timestamp {
                            let activityDate = timestamp.dateValue()
                            activityDates.append(activityDate)
                            print("   - \(dateFormatter.string(from: activityDate)) - Event: \(data["event_id"] ?? "Unknown")")
                        }
                    }
                }
                
                var chartData: [WeeklyChallengeChartData] = []
                var hasAttendedThisWeek = false
                
                for i in 0..<4 {
                    let weeksAgo = 3 - i
                    let targetDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentDate) ?? currentDate
                    
                    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else {
                        continue
                    }
                    
                    let startOfWeek = weekInterval.start
                    let endOfWeek = weekInterval.end
                    let label = weeksAgo == 0 ? "This Week" : "\(weeksAgo)w ago"
                    
                    let activitiesInWeek = activityDates.filter { activityDate in
                        activityDate >= startOfWeek && activityDate < endOfWeek
                    }
                    
                    let hasCompleted = !activitiesInWeek.isEmpty
                    chartData.append(WeeklyChallengeChartData(label: label, count: hasCompleted ? 1 : 0))
                    
                    if weeksAgo == 0 {
                        hasAttendedThisWeek = hasCompleted
                    }
                }
                
                DispatchQueue.main.async {
                    self.hasAttended = hasAttendedThisWeek
                    print("🔄 Final hasAttended: \(self.hasAttended)")
                }
                
                completion(.success(chartData))
            }
    }
    
    // ✅ CAMBIO PRINCIPAL: Esta función ahora usa EventFactory
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
            
            // 🎯 AQUÍ USAMOS EL FACTORY - Reemplaza las 80+ líneas de parseEvent
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
        case 6..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<21:
            return "evening"
        default:
            return "night"
        }
    }
    

}
