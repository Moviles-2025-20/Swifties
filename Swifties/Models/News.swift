//
//  News.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 24/11/25.
//

import Foundation
import FirebaseFirestore

struct News: Codable {
    @DocumentID var id: String?
    let eventId: String
    let description: String
    let photoUrl: String
    var ratings: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case description
        case photoUrl = "photo_url"
        case ratings
    }
}
