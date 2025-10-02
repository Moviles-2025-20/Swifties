//
//  Event.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

import Foundation
import FirebaseFirestore

struct Event: Codable, Identifiable {
    @DocumentID var id: String?
    let title: String?
    let name: String
    let description: String
    let type: String?
    let category: String
    let active: Bool?
    let eventType: [String]?
    let location: Location?
    let schedule: Schedule
    let metadata: Metadata?
    let stats: EventStats?
    let weatherDependent: Bool?
    let created: Timestamp? 
    
    struct Location: Codable {
        let city: String
        let type: String
        let address: String
        let coordinates: [Double]
    }
    
    struct Schedule: Codable {
        let days: [String]
        let times: [String]
    }
    
    struct Metadata: Codable {
        let imageUrl: String
        let tags: [String]
        let durationMinutes: Int
        let cost: String
        
        enum CodingKeys: String, CodingKey {
            case imageUrl = "image_url"
            case tags
            case durationMinutes = "duration_minutes"
            case cost
        }
    }
    
    struct EventStats: Codable {
        let popularity: Int
        let totalCompletions: Int
        let rating: Double
        
        enum CodingKeys: String, CodingKey {
            case popularity
            case totalCompletions = "total_completions"
            case rating
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title, name, description, type, category, active
        case eventType = "EventType"
        case location, schedule, metadata, stats
        case weatherDependent = "weather_dependent"
        case created
    }
    // Custom decoder to support both "EventType" and "eventType" keys
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.category = try container.decode(String.self, forKey: .category)
        self.active = try container.decodeIfPresent(Bool.self, forKey: .active)
        // Try both "EventType" and "eventType"
        if let eventType = try container.decodeIfPresent([String].self, forKey: .eventType) {
            self.eventType = eventType
        } else {
            // Try lowercase "eventType"
            let rawContainer = try decoder.container(keyedBy: LowercaseEventTypeCodingKey.self)
            self.eventType = try rawContainer.decodeIfPresent([String].self, forKey: .eventType)
        }
        self.location = try container.decodeIfPresent(Location.self, forKey: .location)
        self.schedule = try container.decode(Schedule.self, forKey: .schedule)
        self.metadata = try container.decodeIfPresent(Metadata.self, forKey: .metadata)
        self.stats = try container.decodeIfPresent(EventStats.self, forKey: .stats)
        self.weatherDependent = try container.decodeIfPresent(Bool.self, forKey: .weatherDependent)
        self.created = try container.decodeIfPresent(Timestamp.self, forKey: .created)
    }

    // Helper CodingKey for lowercase "eventType"
    private struct LowercaseEventTypeCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
        static let eventType = LowercaseEventTypeCodingKey(stringValue: "eventType")!
    }
}
