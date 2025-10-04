//
//  HomeViewModel.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 4/10/25.
//

import FirebaseAuth
import FirebaseFirestore
import Combine

struct RecommendationResponse: Codable {
    let user_id: String
    let recommendations: [RecommendationItem]
    let count: Int
}

struct RecommendationItem: Codable {
    let id: String
    let title: String
    let category: String
    let score: Double
}

@MainActor
final class HomeViewModel: ObservableObject {
    let db = Firestore.firestore(database: "default")
    let eventListViewModel = EventListViewModel()
    @Published var recommendations: [Event] = []
    
    init() {
        let settings = FirestoreSettings()
        self.db.settings = settings
    }
    
    // MARK: - Get Recommendations
    func getRecommendations() async {
        let defaultResults: [String] = [
            "19ph2WwBuiuI0Rgw7t5F",
            "1XrXxsVrJWnFCsmDJ3YH",
            "6avFMINUtpniHV2EIl6m",
            "LX7WvPRQrAgPQ40GEhOy",
            "SdmE00SDRbcclnQ0lvlf"
        ]
        
        guard let userID = Auth.auth().currentUser?.uid else {
            print("⚠️ User not logged in — using default recommendations.")
            await loadRecommendations(from: defaultResults)
            return
        }
        
        // Construct URL safely
        guard let url = URL(string: "https://us-central1-parchandes-7e096.cloudfunctions.net/get_recommendations?user_id=\(userID)") else {
            print("⚠️ Invalid URL — using default recommendations.")
            await loadRecommendations(from: defaultResults)
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 20 // optional safety
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response — using defaults")
                await loadRecommendations(from: defaultResults)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("⚠️ Server responded with non-200 — using defaults")
                await loadRecommendations(from: defaultResults)
                return
            }
            
            // Try decoding response as array of dicts with 'id'
            let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: data)
            let eventIDs = decoded.recommendations.map { $0.id }
            await loadRecommendations(from: eventIDs)
        } catch {
            print("❌ Error fetching recommendations: \(error.localizedDescription)")
            await loadRecommendations(from: defaultResults)
        }
    }
    
    // MARK: - Load Events from Firestore
    private func loadRecommendations(from eventIDs: [String]) async {
        var tempEvents: [Event] = []
        
        for eventID in eventIDs {
            do {
                let document = try await db.collection("events").document(eventID).getDocument()
                
                if let data = document.data(),
                   let event = eventListViewModel.parseEvent(documentId: eventID, data: data) {
                    tempEvents.append(event)
                } else {
                    print("⚠️ No valid data for document \(eventID)")
                }
            } catch {
                print("❌ Firestore fetch failed for \(eventID): \(error.localizedDescription)")
            }
        }
        
        // Update published property on main thread
        recommendations = tempEvents
    }
    
    // Fetch all events for map and other listings
    func getAllEvents() async throws -> [Event] {
        let snapshot = try await db.collection("events").getDocuments()
        let events: [Event] = snapshot.documents.compactMap { doc in
            eventListViewModel.parseEvent(documentId: doc.documentID, data: doc.data())
        }
        return events
    }
}

