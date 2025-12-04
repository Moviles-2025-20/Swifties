// Comment.swift
// Firestore model for a comment document stored in the top-level "comments" collection.

import Foundation
import FirebaseFirestore

struct Metadata: Codable {
    let imageURL: String?
    let title: String
    let text: String
        
    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case title
        case text 
    }
}

struct Comment: Codable {
    @DocumentID var id: String?
    let created: Date
    let eventId: String
    let userId: String
    let metadata: Metadata
    let rating: Int?
    let emotion: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case created
        case eventId = "event_id"
        case userId = "user_id"
        case metadata
        case rating
        case emotion
    }
}
