//
//  HomeViewModel.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 4/10/25.
//

import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    let db = Firestore.firestore(database: "default")
    // ❌ Ya no necesitas esta línea - EventListViewModel ya no tiene parseEvent
    // let eventListViewModel = EventListViewModel()
    @Published var recommendations: [Event] = []
    
    init() {
        // Initialize Firestore and configure settings
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true // optional offline cache
        self.db.settings = settings
    }
    
    // TODO: Add functionality of the model via REST or FAST API
    func getRecommendations() async throws -> [Event] {
        // let userID = Auth.auth().currentUser?.uid
        let searchResults: [String] = ["19ph2WwBuiuI0Rgw7t5F",
                                       "1XrXxsVrJWnFCsmDJ3YH",
                                       "6avFMINUtpniHV2EIl6m",
                                       "LX7WvPRQrAgPQ40GEhOy",
                                       "SdmE00SDRbcclnQ0lvlf"]
        
        // Reset to avoid duplicates when called multiple times
        recommendations.removeAll()
        
        for eventID in searchResults {
            let document = try await db.collection("events").document(eventID).getDocument()
            
          
            if let event = EventFactory.createEvent(from: document) {
                recommendations.append(event)
            } else {
                print("No valid data for document \(eventID)")
                continue
            }
        }
        
        return recommendations
    }
    
    // Fetch all events for map and other listings
    func getAllEvents() async throws -> [Event] {
        let snapshot = try await db.collection("events").getDocuments()
        
        // ✅ Use EventFactory directly
        let events: [Event] = snapshot.documents.compactMap { doc in
            EventFactory.createEvent(from: doc)
        }
        
        return events
    }
}
