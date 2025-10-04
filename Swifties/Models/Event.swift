import Foundation

// MARK: - Main Event Structure
struct Event: Codable {
    let activetrue: Bool
    let category: String
    let created: String
    let description: String
    let eventType: String
    let location: EventLocation
    let metadata: EventMetadata
    let name: String
    let schedule: EventSchedule
    let stats: EventStats
    let title: String
    let type: String
    let weatherDependent: Bool
    
    enum CodingKeys: String, CodingKey {
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
