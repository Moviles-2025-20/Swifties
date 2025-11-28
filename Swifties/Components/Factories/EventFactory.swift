import FirebaseFirestore

class EventFactory {
    // Method for QueryDocumentSnapshot (used in queries)
    static func createEvent(from document: QueryDocumentSnapshot) -> Event? {
        let data = document.data()
        return parseEventData(data, documentId: document.documentID)
    }
    
    // Method for DocumentSnapshot (used in getDocument)
    static func createEvent(from document: DocumentSnapshot) -> Event? {
        guard let data = document.data() else { return nil }
        return parseEventData(data, documentId: document.documentID)
    }
    
    private static func parseEventData(_ data: [String: Any], documentId: String) -> Event? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String else {
            return nil
        }
        
        let location = parseLocation(from: data["location"] as? [String: Any])
        let schedule = parseSchedule(from: data["schedule"] as? [String: Any])
        let metadata = parseMetadata(from: data["metadata"] as? [String: Any])
        let stats = parseStats(from: data["stats"] as? [String: Any])
        
        var event = Event(
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
        
        // CRITICAL: Set the document ID
        event.id = documentId
        
        return event
    }
    
    private static func parseLocation(from data: [String: Any]?) -> EventLocation {
        guard let data = data else { return EventLocation(address: "", city: "", coordinates: [], type: "") }
        return EventLocation(
            address: data["address"] as? String ?? "",
            city: data["city"] as? String ?? "",
            coordinates: data["coordinates"] as? [Double] ?? [],
            type: data["type"] as? String ?? ""
        )
    }
    
    private static func parseSchedule(from data: [String: Any]?) -> EventSchedule {
        guard let data = data else { return EventSchedule(days: [], times: []) }
        return EventSchedule(
            days: data["days"] as? [String] ?? [],
            times: data["times"] as? [String] ?? []
        )
    }
    
    private static func parseMetadata(from data: [String: Any]?) -> EventMetadata {
        guard let data = data else {
            return EventMetadata(cost: EventCost(amount: 0, currency: "COP"), durationMinutes: 0, imageUrl: "", tags: [])
        }
        
        let cost: EventCost
        if let costData = data["cost"] as? [String: Any] {
            cost = EventCost(
                amount: costData["amount"] as? Int ?? 0,
                currency: costData["currency"] as? String ?? "COP"
            )
        } else {
            cost = EventCost(amount: 0, currency: "COP")
        }
        
        return EventMetadata(
            cost: cost,
            durationMinutes: data["duration_minutes"] as? Int ?? 0,
            imageUrl: data["image_url"] as? String ?? "",
            tags: data["tags"] as? [String] ?? []
        )
    }
    
    private static func parseStats(from data: [String: Any]?) -> EventStats {
        guard let data = data else { return EventStats(popularity: 0, rating: 0, ratingList: [], totalCompletions: 0) }
        return EventStats(
            popularity: data["popularity"] as? Int ?? 0,
            rating: data["rating"] as? Int ?? 0,
            ratingList: data["rating_list"] as? [Int?] ?? [],
            totalCompletions: data["total_completions"] as? Int ?? 0
        )
    }
}
