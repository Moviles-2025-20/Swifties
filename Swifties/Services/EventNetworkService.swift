//
//  EventNetworkService.swift
//  Swifties
//
//  Created by Imac  on 25/10/25.
//

import Foundation
import FirebaseFirestore

class EventNetworkService {
    static let shared = EventNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {
        let settings = FirestoreSettings()
        db.settings = settings
    }
    
    func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.failure(NSError(
                    domain: "EventNetworkService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No documents found"]
                )))
                return
            }
            
            let events = documents.compactMap { EventFactory.createEvent(from: $0) }
            print("\(events.count) events fetched from Firestore")
            completion(.success(events))
        }
    }
}
