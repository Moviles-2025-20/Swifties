//
//  EventDetailViewModel.swift
//  Swifties
//
//

import Foundation
import FirebaseFirestore
import Combine

class EventDetailViewModel: ObservableObject {
    @Published var event: Event?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var comments: [Comment] = []
    
    // Derived ratings from loaded comments
    @Published var averageRating: Double = 0.0
    // Index 0 -> 1-star, ..., Index 4 -> 5-star counts
    @Published var ratingCounts: [Int] = [0, 0, 0, 0, 0]

    // Convenience: total number of valid ratings
    var totalRatings: Int { ratingCounts.reduce(0, +) }
    
    private let eventId: String
    let db = Firestore.firestore(database: "default")
    private var commentsListener: ListenerRegistration? = nil
    
    init(eventId: String) {
        self.eventId = eventId
        
        // Configure Firestore settings
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true
        firestore.settings = settings
    }
    
    func loadEventDetail() {
        guard !eventId.isEmpty else {
            errorMessage = "Invalid event ID"
            return
        }

        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()

        var loadedEvent: Event?
        var loadedComments: [Comment] = []
        var firstError: Error?

        // Fetch event
        self.db.collection("events").document(self.eventId).getDocument { document, error in
            if let error = error {
                if firstError == nil { firstError = error }
                group.leave()
                return
            }
            guard let document = document, document.exists else {
                if firstError == nil {
                    firstError = NSError(domain: "EventDetailViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
                }
                group.leave()
                return
            }
            let data = document.data() ?? [:]
            loadedEvent = self.parseEvent(documentId: document.documentID, data: data)
        }

        // Fetch comments for this event
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.db.collection("comments")
                .whereField("event_id", isEqualTo: self.eventId)
                .order(by: "created", descending: true)
                .getDocuments { snapshot, error in
                    if let error = error {
                        if firstError == nil { firstError = error }
                        group.leave()
                        return
                    }
                    guard let snapshot = snapshot else {
                        group.leave()
                        return
                    }
                    let parsed: [Comment] = snapshot.documents.compactMap { doc in
                        do { return try doc.data(as: Comment.self) } catch { return nil }
                    }
                    loadedComments = parsed
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            self.isLoading = false
            if let error = firstError {
                self.errorMessage = error.localizedDescription
            }
            self.event = loadedEvent
            self.comments = loadedComments
            self.recalculateRatings()
        }
    }
    
    func loadComments(event_id: String) async {
        do {
            let snapshot = try await db.collection("comments")
                .whereField("event_id", isEqualTo: event_id)
                .order(by: "created", descending: true)
                .getDocuments()

            let parsed: [Comment] = snapshot.documents.compactMap { doc -> Comment? in
                do {
                    return try doc.data(as: Comment.self)
                } catch {
                    print("Failed to parse comment \(doc.documentID): \(error)")
                    return nil
                }
            }

            await MainActor.run {
                self.comments = parsed
                self.recalculateRatings()
                print("Loaded \(parsed.count) comments for event \(event_id)")
            }
        } catch {
            print("❌ Error fetching comments: \(error.localizedDescription)")
            await MainActor.run {
                self.comments = []
            }
        }
    }

    // MARK: - Real-time Comments Listener
    func startListeningForComments(forEventId: String?) {
        // If we don't have an event id, exit as requested
        guard let forEventId = forEventId, !forEventId.isEmpty else { return }

        // Remove any existing listener to avoid duplicates
        commentsListener?.remove()

        commentsListener = db.collection("comments")
            .whereField("event_id", isEqualTo: forEventId)
            .order(by: "created", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening for comments: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { 
                        self.comments = [] 
                    }
                    return
                }
                let parsed: [Comment] = docs.compactMap { doc in
                    try? doc.data(as: Comment.self)
                }
                DispatchQueue.main.async {
                    self.comments = parsed
                    self.recalculateRatings()
                    self.event?.stats.ratingList = self.comments.map(\.rating)
                }
            }
    }

    func stopListeningForComments() {
        commentsListener?.remove()
        commentsListener = nil
    }
    
    // MARK: - Ratings aggregation
    private func recalculateRatings() {
        // Filter to valid ratings 1...5
        let validComments: [Comment] = comments.filter { comment in
            if let rating = comment.rating { return (1...5).contains(rating) }
            return false
        }

        // Reset counts
        var counts = [0, 0, 0, 0, 0]
        for comment in validComments {
            if let rating = comment.rating, (1...5).contains(rating) {
                counts[rating - 1] += 1
            }
        }

        let total = counts.reduce(0, +)
        let avg: Double
        if total > 0 {
            let sum = counts.enumerated().reduce(0) { partial, pair in
                let (index, count) = pair
                return partial + (index + 1) * count
            }
            avg = Double(sum) / Double(total)
        } else {
            avg = 0.0
        }

        // Publish on main thread
        DispatchQueue.main.async {
            self.ratingCounts = counts
            self.averageRating = avg
        }
    }
    
    private func parseEvent(documentId: String, data: [String: Any]) -> Event? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String else {
            print("Missing required fields")
            return nil
        }
        
        // Location parsing
        var location = EventLocation(address: "", city: "", coordinates: [], type: "")
        if let locationData = data["location"] as? [String: Any] {
            location = EventLocation(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                coordinates: locationData["coordinates"] as? [Double] ?? [],
                type: locationData["type"] as? String ?? ""
            )
        }
        
        // Schedule parsing
        var schedule = EventSchedule(days: [], times: [])
        if let scheduleData = data["schedule"] as? [String: Any] {
            schedule = EventSchedule(
                days: scheduleData["days"] as? [String] ?? [],
                times: scheduleData["times"] as? [String] ?? []
            )
        }
        
        // Metadata parsing
        var metadata = EventMetadata(
            cost: EventCost(amount: 0, currency: "COP"),
            durationMinutes: 0,
            imageUrl: "",
            tags: []
        )
        if let metadataData = data["metadata"] as? [String: Any] {
            var cost = EventCost(amount: 0, currency: "COP")
            if let costData = metadataData["cost"] as? [String: Any] {
                let amount = costData["amount"] as? Int ?? 0
                let currency = costData["currency"] as? String ?? "COP"
                cost = EventCost(amount: amount, currency: currency)
            }
            
            metadata = EventMetadata(
                cost: cost,
                durationMinutes: metadataData["duration_minutes"] as? Int ?? 0,
                imageUrl: metadataData["image_url"] as? String ?? "",
                tags: metadataData["tags"] as? [String] ?? []
            )
        }
        
        // Stats parsing
        var stats = EventStats(popularity: 0, rating: 0, ratingList: [], totalCompletions: 0)
        if let statsData = data["stats"] as? [String: Any] {
            stats = EventStats(
                popularity: statsData["popularity"] as? Int ?? 0,
                rating: statsData["rating"] as? Int ?? 0,
                ratingList: statsData["rating_list"] as? [Int?] ?? [],
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
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

