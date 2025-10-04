//
//  WishMeLuckEvent.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 4/10/25.
//
//
//  WishMeLuckEvent.swift
//  Swifties
//
//  Created on 10/4/25.
//

import Foundation

struct WishMeLuckEvent: Codable, Identifiable {
    let id: String
    let title: String
    let imageUrl: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageUrl = "image_url"
        case description
    }
    
    init(id: String, title: String, imageUrl: String, description: String) {
        self.id = id
        self.title = title
        self.imageUrl = imageUrl
        self.description = description
    }
    
    // Custom decoder to handle nested Firebase structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        
        // Try to get title from multiple possible fields
        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else {
            title = "Untitled Event"
        }
        
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? "No description available"
    }
    
    // Helper to create from Event model
    static func fromEvent(_ event: Event) -> WishMeLuckEvent {
        return WishMeLuckEvent(
            id: event.id ?? UUID().uuidString,
            title: event.title,
            imageUrl: event.metadata.imageUrl,
            description: event.description
        )
    }
}
