import Foundation
import FirebaseFirestore

// MARK: - Main Event Structure (para Firebase)
struct Event: Identifiable {
    @DocumentID var id: String?
    let activetrue: Bool
    let category: String
    let created: String
    let description: String
    let eventType: String
    let location: EventLocation?
    let metadata: EventMetadata
    let name: String
    let schedule: EventSchedule
    let stats: EventStats
    let title: String
    let type: String
    let weatherDependent: Bool
}

// MARK: - Codable version for local storage
struct CodableEvent: Codable {
    var id: String?
    let activetrue: Bool
    let category: String
    let created: String
    let description: String
    let eventType: String
    let location: EventLocation?
    let metadata: EventMetadata
    let name: String
    let schedule: EventSchedule
    let stats: EventStats
    let title: String
    let type: String
    let weatherDependent: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case activetrue
        case category
        case created
        case description
        case eventType = "event_type"
        case location
        case metadata
        case name
        case schedule
        case stats
        case title
        case type
        case weatherDependent = "weather_dependent"
    }
}

// MARK: - Conversión bidireccional
extension Event {
    func toCodable() -> CodableEvent {
        CodableEvent(
            id: id,
            activetrue: activetrue,
            category: category,
            created: created,
            description: description,
            eventType: eventType,
            location: location,
            metadata: metadata,
            name: name,
            schedule: schedule,
            stats: stats,
            title: title,
            type: type,
            weatherDependent: weatherDependent
        )
    }
    
    static func from(codable: CodableEvent) -> Event {
        var event = Event(
            activetrue: codable.activetrue,
            category: codable.category,
            created: codable.created,
            description: codable.description,
            eventType: codable.eventType,
            location: codable.location,
            metadata: codable.metadata,
            name: codable.name,
            schedule: codable.schedule,
            stats: codable.stats,
            title: codable.title,
            type: codable.type,
            weatherDependent: codable.weatherDependent
        )
        event._id.wrappedValue = codable.id
        return event
    }
}

// MARK: - Location
struct EventLocation: Codable {
    let address: String
    let city: String
    let coordinates: [Double]
    let type: String
}

// MARK: - Metadata
struct EventMetadata: Codable {
    let cost: EventCost
    let durationMinutes: Int
    let imageUrl: String
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case cost
        case durationMinutes = "duration_minutes"
        case imageUrl = "image_url"
        case tags
    }
}

// MARK: - Cost
struct EventCost: Codable {
    let amount: Int
    let currency: String
}

// MARK: - Schedule
struct EventSchedule: Codable {
    let days: [String]
    let times: [String]
}

// MARK: - Stats
struct EventStats: Codable {
    let popularity: Int
    let rating: Int
    let totalCompletions: Int
    
    enum CodingKeys: String, CodingKey {
        case popularity
        case rating
        case totalCompletions = "total_completions"
    }
}
