//
//  NewsFactory.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 27/11/25.
//

import FirebaseFirestore

class NewsFactory {
    static func createNews(from document: DocumentSnapshot) -> News? {
        guard let data = document.data() else { return nil }
        return parseNewsData(data, documentId: document.documentID)
    }
    
    private static func parseNewsData(_ data: [String: Any], documentId: String) -> News? {
        guard let eventId = data["event_id"] as? String,
              let description = data["description"] as? String,
              let photoUrl = data["photo_url"] as? String,
              let ratings = data["ratings"] as? [String] else {
            return nil
        }
        
        return News(
            id: documentId,
            eventId: eventId,
            description: description,
            photoUrl: photoUrl,
            ratings: ratings
        )
    }
}

