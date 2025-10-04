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
    let firestore = Firestore.firestore(database: "default")
    let eventListViewModel = EventListViewModel()
    @Published var recommendations: [Event] = []
    
    init() {
        // Initialize Firestore and configure settings
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true // optional offline cache
        self.firestore.settings = settings
    }
    
    func getRecommendations() async throws -> [Event] {
        // let userID = Auth.auth().currentUser?.uid
        let searchResults: [String] = ["19ph2WwBuiuI0Rgw7t5F",
                                       "1XrXxsVrJWnFCsmDJ3YH",
                                       "6avFMINUtpniHV2EIl6m",
                                       "LX7WvPRQrAgPQ40GEhOy",
                                       "SdmE00SDRbcclnQ0lvlf"] // TODO: Add functionality of the model via REST or FAST API
                
        for eventID in searchResults {
            let document = try await firestore.collection("events").document(eventID).getDocument()
            if let data = document.data(),
                let event = eventListViewModel.parseEvent(documentId: eventID, data: data) {
                recommendations.append(event)
            } else {
                print("No valid data for document \(eventID)")
                continue
            }
        }
        
        return recommendations
    }
}
