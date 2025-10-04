//
//  UserInfoView.swift
//  Swifties
//
//  Created by Assistant on 3/10/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models
struct FreeTimeSlot: Identifiable {
    let id = UUID()
    let day: String
    let start: String
    let end: String
    
    init(data: [String: Any]) {
        self.day = data["day"] as? String ?? ""
        self.start = data["start"] as? String ?? ""
        self.end = data["end"] as? String ?? ""
    }
}

struct UserInfoView: View {
    @State private var freeTimeSlots: [FreeTimeSlot] = []
    @State private var availableEvents: [Event] = []
    @State private var allEvents: [Event] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomTopBar(title: "Available Events", showNotificationButton: true) {
                    print("Notification tapped")
                }
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading your available events...")
                        .foregroundColor(.primary)
                    Spacer()
                } else if let error = errorMessage {
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
                        VStack(spacing: 20) {
                            // Free Time Slots Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Free Time")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                if freeTimeSlots.isEmpty {
                                    Text("No free time slots configured")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(freeTimeSlots) { slot in
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.orange)
                                                Text(slot.day)
                                                    .fontWeight(.semibold)
                                                Spacer()
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text("\(slot.start) - \(slot.end)")
                                                    .font(.subheadline)
                                            }
                                            .padding()
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Available Events Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Events That Fit Your Schedule")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(availableEvents.count)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal)
                                
                                if availableEvents.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                        Text("No events match your free time")
                                            .foregroundColor(.secondary)
                                        Text("Try adjusting your availability or check back later")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(availableEvents, id: \.title) { event in
                                            NavigationLink(destination: EventDetailView(event: event)) {
                                                EventInfo(
                                                    imagePath: event.metadata.imageUrl,
                                                    title: event.name,
                                                    titleColor: Color.green,
                                                    description: event.description,
                                                    timeText: event.schedule.times.first ?? "Time TBD",
                                                    walkingMinutes: 5,
                                                    location: event.location.address
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.top, 16)
                    }
                }
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                loadData()
            }
        }
    }
    
    // MARK: - Load Data
    private func loadData() {
        isLoading = true
        errorMessage = nil
        
        let group = DispatchGroup()
        
        // Load free time slots
        group.enter()
        fetchFreeTimeSlots { result in
            switch result {
            case .success(let slots):
                freeTimeSlots = slots
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            group.leave()
        }
        
        // Load all events
        group.enter()
        fetchEvents { result in
            switch result {
            case .success(let events):
                allEvents = events
            case .failure(let error):
                if errorMessage == nil {
                    errorMessage = error.localizedDescription
                }
            }
            group.leave()
        }
        
        // After both complete, filter events
        group.notify(queue: .main) {
            filterAvailableEvents()
            isLoading = false
        }
    }
    
    // MARK: - Fetch Free Time Slots
    private func fetchFreeTimeSlots(completion: @escaping (Result<[FreeTimeSlot], Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
            return
        }
        
        let db = Firestore.firestore(database: "default")
        let userRef = db.collection("users").document(currentUser.uid)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let preferences = data["preferences"] as? [String: Any],
                  let notifications = preferences["notifications"] as? [String: Any],
                  let slotsData = notifications["free_time_slots"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Free time slots not found"])))
                return
            }
            
            let slots = slotsData.map { FreeTimeSlot(data: $0) }
            completion(.success(slots))
        }
    }
    
    // MARK: - Fetch Events
    private func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        let db = Firestore.firestore(database: "default")
        
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let events = documents.compactMap { doc -> Event? in
                parseEvent(documentId: doc.documentID, data: doc.data())
            }
            
            completion(.success(events))
        }
    }
    
    // MARK: - Parse Event (same as EventListViewModel)
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
    
    // MARK: - Filter Available Events
    private func filterAvailableEvents() {
        availableEvents = allEvents.filter { event in
            // Check if event is active
            guard event.activetrue else { return false }
            
            // Check if any event day/time matches user's free time
            for eventDay in event.schedule.days {
                for eventTime in event.schedule.times {
                    for slot in freeTimeSlots {
                        if eventDay.lowercased() == slot.day.lowercased() &&
                           isTimeInRange(eventTime: eventTime, slotStart: slot.start, slotEnd: slot.end) {
                            return true
                        }
                    }
                }
            }
            
            return false
        }
    }
    
    // MARK: - Check if Time is in Range
    private func isTimeInRange(eventTime: String, slotStart: String, slotEnd: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        guard let event = formatter.date(from: eventTime),
              let start = formatter.date(from: slotStart),
              let end = formatter.date(from: slotEnd) else {
            return false
        }
        
        return event >= start && event <= end
    }
}

// MARK: - Preview
struct UserInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UserInfoView()
        }
    }
}
