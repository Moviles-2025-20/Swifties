//
//  WeeklyChallengeView.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct WeeklyChallengeView: View {
    @StateObject private var viewModel = WeeklyChallengeViewModel()
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomTopBar(title: "Weekly Challenge", showNotificationButton: true) {
                    print("Notification tapped")
                }
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading challenge...")
                        .foregroundColor(.primary)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("⚠️")
                            .font(.system(size: 50))
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Challenge Event Card
                            if let event = viewModel.challengeEvent {
                                VStack(spacing: 0) {
                                    // Event Image
                                    if let url = URL(string: event.metadata.imageUrl), !event.metadata.imageUrl.isEmpty {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Challenge Badge
                                        HStack {
                                            Image(systemName: "star.circle.fill")
                                                .foregroundColor(.yellow)
                                            Text("THIS WEEK'S CHALLENGE")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.orange)
                                            Spacer()
                                        }
                                        
                                        // Event Title
                                        Text(event.title)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        // Event Description
                                        Text(event.description)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                        
                                        // Event Details
                                        VStack(spacing: 8) {
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.orange)
                                                Text(event.schedule.days.joined(separator: ", "))
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text(event.schedule.times.first ?? "TBD")
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Image(systemName: "mappin.circle")
                                                    .foregroundColor(.red)
                                                Text(event.location?.address ?? "")
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        
                                        // Attend Button
                                        Button(action: {
                                            viewModel.markAsAttending()
                                        }) {
                                            HStack {
                                                Image(systemName: viewModel.hasAttended ? "checkmark.circle.fill" : "hand.raised.fill")
                                                Text(viewModel.hasAttended ? "Challenge Accepted!" : "I'm Going to Attend")
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(viewModel.hasAttended ? Color.green : Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                        .disabled(viewModel.hasAttended)
                                    }
                                    .padding()
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("No challenge available this week")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                            
                            // Stats Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Progress")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                // Stats Grid
                                HStack(spacing: 12) {
                                    // Total Challenges
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "trophy.fill")
                                                .foregroundColor(.yellow)
                                                .font(.title2)
                                            Spacer()
                                        }
                                        Text("\(viewModel.totalChallenges)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.orange)
                                        Text("Total Challenges")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    
                                    // This Week
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                            Spacer()
                                        }
                                        Text("\(viewModel.hasAttended ? 1 : 0)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(viewModel.hasAttended ? .green : .blue)
                                        Text("This Week")
                                            .font(.caption)
                                            .foregroundColor(viewModel.hasAttended ? .green : .secondary)

                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                
                                // Last 4 Weeks Chart
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Weekly Challenge Streak")
                                            .font(.headline)
                                        Spacer()
                                        Text("Last 4 Weeks")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if viewModel.last30DaysData.isEmpty {
                                        VStack(spacing: 12) {
                                            Image(systemName: "chart.bar.xaxis")
                                                .font(.system(size: 40))
                                                .foregroundColor(.secondary.opacity(0.5))
                                            Text("No activity yet")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text("Complete your first weekly challenge!")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                    } else {
                                        VStack(spacing: 16) {
                                            // Weekly Challenge Indicators
                                            HStack(alignment: .center, spacing: 12) {
                                                ForEach(viewModel.last30DaysData) { data in
                                                    let isCompleted = data.count > 0
                                                    
                                                    VStack(spacing: 12) {
                                                        // Week Label on top
                                                        Text(data.label)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                            .multilineTextAlignment(.center)
                                                            .lineLimit(2)
                                                            .frame(height: 30)
                                                        
                                                        // Challenge Status Indicator
                                                        ZStack {
                                                            Circle()
                                                                .fill(isCompleted ?
                                                                      LinearGradient(
                                                                        colors: [Color.green, Color.green.opacity(0.7)],
                                                                        startPoint: .top,
                                                                        endPoint: .bottom
                                                                      ) :
                                                                      LinearGradient(
                                                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                                                        startPoint: .top,
                                                                        endPoint: .bottom
                                                                      )
                                                                )
                                                                .frame(width: 60, height: 60)
                                                            
                                                            if isCompleted {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.white)
                                                            } else {
                                                                Image(systemName: "xmark.circle")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.gray.opacity(0.5))
                                                            }
                                                        }
                                                        
                                                        // Status Text
                                                        Text(isCompleted ? "Completed" : "Missed")
                                                            .font(.caption2)
                                                            .fontWeight(isCompleted ? .semibold : .regular)
                                                            .foregroundColor(isCompleted ? .green : .secondary)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                            .padding(.vertical, 20)
                                            
                                            // Summary
                                            HStack(spacing: 20) {
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(Color.green)
                                                        .frame(width: 12, height: 12)
                                                    Text("Completed: \(viewModel.last30DaysData.filter { $0.count > 0 }.count)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 12, height: 12)
                                                    Text("Missed: \(viewModel.last30DaysData.filter { $0.count == 0 }.count)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.loadChallenge()
            }
        }
    }
}

// MARK: - ViewModel
class WeeklyChallengeViewModel: ObservableObject {
    @Published var challengeEvent: Event?
    @Published var totalChallenges: Int = 0
    @Published var last30DaysData: [ChartData] = []
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
        
        // Load random event
        group.enter()
        loadRandomEvent { result in
            switch result {
            case .success(let event):
                DispatchQueue.main.async {
                    self.challengeEvent = event
                    print("✅ Event loaded: \(event.name)")
                }
                // Check if user has already attended this specific event
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
        
        // Load user stats from UserActivity
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
        
        // Load last 30 days data
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
        
        db.collection("UserActivity").addDocument(data: activityData) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error saving activity: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Error saving activity: \(error.localizedDescription)"
                }
            } else {
                print("✅ Activity saved successfully!")
                DispatchQueue.main.async {
                    self.hasAttended = true
                    self.totalChallenges += 1
                    self.loadChallenge()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkIfUserAttended(userId: String, eventId: String, completion: @escaping () -> Void) {
        print("🔍 Checking attendance for user: \(userId), event: \(eventId)")
        
        db.collection("UserActivity")
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
                
                if let documents = snapshot?.documents {
                    for doc in documents {
                        print("📄 Document ID: \(doc.documentID)")
                        print("📄 Data: \(doc.data())")
                    }
                }
                
                DispatchQueue.main.async {
                    self.hasAttended = attended
                    print("🔄 Updated hasAttended to: \(self.hasAttended)")
                }
                completion()
            }
    }
    
    private func loadUserChallengeStats(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        print("📊 Loading user challenge stats for: \(userId)")
        
        db.collection("UserActivity")
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
    
    private func loadLast30DaysData(userId: String, completion: @escaping (Result<[ChartData], Error>) -> Void) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        let currentDate = Date()
        
        // Calculate date from 30 days ago
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: currentDate) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error calculating date"])))
            return
        }
        
        print("📊 Loading activities from last 30 days")
        print("📅 Current date: \(currentDate)")
        print("📅 30 days ago: \(thirtyDaysAgo)")
        
        // Get ALL user activities (no time filter in the query)
        // The time filter is applied locally in Swift
        db.collection("UserActivity")
            .whereField("user_id", isEqualTo: userId)
            .whereField("type", isEqualTo: "weekly_challenge")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading activities: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy HH:mm"
                dateFormatter.timeZone = calendar.timeZone
                
                // Obtener todas las fechas de actividades
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
                
                // Prepare the last 4 weeks
                var chartData: [ChartData] = []
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
                    
                    print("\n📅 Checking week: \(label)")
                    print("   Range: \(dateFormatter.string(from: startOfWeek)) to \(dateFormatter.string(from: endOfWeek))")
                    
                    // Count how many activities fall in this week
                    let activitiesInWeek = activityDates.filter { activityDate in
                        activityDate >= startOfWeek && activityDate < endOfWeek
                    }
                    
                    let hasCompleted = !activitiesInWeek.isEmpty
                    print("   Activities found: \(activitiesInWeek.count)")
                    print("   Status: \(hasCompleted ? "✅ Completed" : "❌ Missed")")
                    
                    if hasCompleted {
                        for activityDate in activitiesInWeek {
                            print("      - \(dateFormatter.string(from: activityDate))")
                        }
                    }
                    
                    chartData.append(ChartData(label: label, count: hasCompleted ? 1 : 0))
                    
                    // If it's the current week, update hasAttended
                    if weeksAgo == 0 {
                        hasAttendedThisWeek = hasCompleted
                    }
                }
                
                print("\n✅ Chart data prepared:")
                for data in chartData {
                    print("   \(data.label): \(data.count > 0 ? "✅ Completed" : "❌ Missed")")
                }
                
                // Update hasAttended on the main thread
                DispatchQueue.main.async {
                    self.hasAttended = hasAttendedThisWeek
                    print("🔄 Final hasAttended: \(self.hasAttended)")
                }
                
                completion(.success(chartData))
            }
    }
    
    private func loadRandomEvent(completion: @escaping (Result<Event, Error>) -> Void) {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.year, from: Date())
        let weekKey = "\(year)-W\(weekOfYear)"
        
        print("🗓️ Loading event for week: \(weekKey)")
        
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No events available"])))
                return
            }
            
            let seed = weekOfYear + (year * 100)
            let index = seed % documents.count
            let selectedDoc = documents[index]
            
            print("🎯 Selected event index: \(index) out of \(documents.count)")
            
            if let event = self.parseEvent(documentId: selectedDoc.documentID, data: selectedDoc.data()) {
                print("✅ Weekly challenge event: \(event.name)")
                completion(.success(event))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse event"])))
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
    
    private func parseEvent(documentId: String, data: [String: Any]) -> Event? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String else {
            return nil
        }
        
        var location = EventLocation(address: "", city: "", coordinates: [], type: "")
        if let locationData = data["location"] as? [String: Any] {
            location = EventLocation(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                coordinates: locationData["coordinates"] as? [Double] ?? [],
                type: locationData["type"] as? String ?? ""
            )
        }
        
        var schedule = EventSchedule(days: [], times: [])
        if let scheduleData = data["schedule"] as? [String: Any] {
            schedule = EventSchedule(
                days: scheduleData["days"] as? [String] ?? [],
                times: scheduleData["times"] as? [String] ?? []
            )
        }
        
        var metadata = EventMetadata(
            cost: EventCost(amount: 0, currency: "COP"),
            durationMinutes: 0,
            imageUrl: "",
            tags: []
        )
        if let metadataData = data["metadata"] as? [String: Any] {
            var cost = EventCost(amount: 0, currency: "COP")
            if let costData = metadataData["cost"] as? [String: Any] {
                cost = EventCost(
                    amount: costData["amount"] as? Int ?? 0,
                    currency: costData["currency"] as? String ?? "COP"
                )
            }
            
            metadata = EventMetadata(
                cost: cost,
                durationMinutes: metadataData["duration_minutes"] as? Int ?? 0,
                imageUrl: metadataData["image_url"] as? String ?? "",
                tags: metadataData["tags"] as? [String] ?? []
            )
        }
        
        var stats = EventStats(popularity: 0, rating: 0, totalCompletions: 0)
        if let statsData = data["stats"] as? [String: Any] {
            stats = EventStats(
                popularity: statsData["popularity"] as? Int ?? 0,
                rating: statsData["rating"] as? Int ?? 0,
                totalCompletions: statsData["total_completions"] as? Int ?? 0
            )
        }
        
        return Event(
            activetrue: data["activetrue"] as? Bool ?? true,
            category: category,
            created: data["created"] as? String ?? "",
            description: description,
            eventType: data["event_type"] as? String ?? "",
            location: location,
            metadata: metadata,
            name: name,
            schedule: schedule,
            stats: stats,
            title: data["title"] as? String ?? "",
            type: data["type"] as? String ?? "",
            weatherDependent: data["weather_dependent"] as? Bool ?? false
        )
    }
}

// MARK: - Event Model
extension Event: Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.name == rhs.name &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description
    }
}

// MARK: - Chart Data Model
struct ChartData: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

// MARK: - Preview
struct WeeklyChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WeeklyChallengeView()
        }
    }
}
