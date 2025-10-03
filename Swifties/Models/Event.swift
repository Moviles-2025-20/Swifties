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
    let eventType: String?  
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
    
    struct Cost: Codable {
        let amount: Int
        let currency: String
        
        var formatted: String {
            if currency == "FREE" || amount == 0 {
                return "FREE"
            }
            return "\(currency) $\(amount)"
        }
    }

    struct Metadata: Codable {
        let imageUrl: String
        let tags: [String]
        let durationMinutes: Int
        let cost: Cost

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
        case eventType = "event_type"
        case location, schedule, metadata, stats
        case weatherDependent = "weather_dependent"
        case created
    }
    
    // Helper computed properties
    var durationFormatted: String {
        guard let metadata = metadata else { return "" }
        let hours = metadata.durationMinutes / 60
        let minutes = metadata.durationMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)min"
        }
    }
}

