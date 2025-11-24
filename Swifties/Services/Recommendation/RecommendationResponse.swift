//
//  RecommendationResponse.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Response Models
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

class RecommendationNetworkService {
    static let shared = RecommendationNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {
        let settings = FirestoreSettings()
        db.settings = settings
    }
    
    func fetchRecommendations(userId: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        let defaultResults: [String] = [
            "19ph2WwBuiuI0Rgw7t5F",
            "1XrXxsVrJWnFCsmDJ3YH",
            "6avFMINUtpniHV2EIl6m",
            "LX7WvPRQrAgPQ40GEhOy",
            "SdmE00SDRbcclnQ0lvlf"
        ]
        
        // Construct URL safely
        guard let url = URL(string: "https://us-central1-parchandes-7e096.cloudfunctions.net/get_recommendations?user_id=\(userId)") else {
            print("⚠️ Invalid URL — using default recommendations.")
            loadEvents(from: defaultResults, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Check for network error
            if let error = error {
                print("❌ Network error: \(error.localizedDescription) — using defaults")
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response — using defaults")
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("⚠️ Server responded with \(httpResponse.statusCode) — using defaults")
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            // Parse response
            guard let data = data else {
                print("❌ No data received — using defaults")
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: data)
                let eventIDs = decoded.recommendations.map { $0.id }
                print("✅ Received \(eventIDs.count) recommendations from API")
                self.loadEvents(from: eventIDs, completion: completion)
            } catch {
                print("❌ Error decoding response: \(error.localizedDescription) — using defaults")
                self.loadEvents(from: defaultResults, completion: completion)
            }
        }.resume()
    }
    
    private func loadEvents(from eventIDs: [String], completion: @escaping (Result<[Event], Error>) -> Void) {
        let group = DispatchGroup()
        var events: [Event] = []
        var fetchError: Error?
        
        for eventID in eventIDs {
            group.enter()
            
            db.collection("events").document(eventID).getDocument { document, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Failed to fetch document \(eventID): \(error.localizedDescription)")
                    if fetchError == nil {
                        fetchError = error
                    }
                    return
                }
                
                if let document = document, let event = EventFactory.createEvent(from: document) {
                    events.append(event)
                } else {
                    print("No valid data for document \(eventID)")
                }
            }
        }
        
        group.notify(queue: .main) {
            if let error = fetchError, events.isEmpty {
                completion(.failure(error))
            } else {
                print("\(events.count) recommendations fetched from Firestore")
                completion(.success(events))
            }
        }
    }
}
