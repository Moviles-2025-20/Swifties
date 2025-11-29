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
        
        guard let url = URL(string: "https://us-central1-parchandes-7e096.cloudfunctions.net/get_recommendations?user_id=\(userId)") else {
            #if DEBUG
            print("⚠️ Invalid URL — using default recommendations.")
            #endif
            loadEvents(from: defaultResults, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                #if DEBUG
                print("❌ Network error: \(error.localizedDescription) — using defaults")
                #endif
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("❌ Invalid response — using defaults")
                #endif
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }

            guard httpResponse.statusCode == 200 else {
                #if DEBUG
                print("⚠️ Server responded with \(httpResponse.statusCode) — using defaults")
                #endif
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            guard let data = data else {
                #if DEBUG
                print("❌ No data received — using defaults")
                #endif
                self.loadEvents(from: defaultResults, completion: completion)
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(RecommendationResponse.self, from: data)
                let eventIDs = decoded.recommendations.map { $0.id }
                #if DEBUG
                print("✅ Received \(eventIDs.count) recommendations from API")
                #endif
                self.loadEvents(from: eventIDs, completion: completion)
            } catch {
                #if DEBUG
                print("❌ Error decoding response: \(error.localizedDescription) — using defaults")
                #endif
                self.loadEvents(from: defaultResults, completion: completion)
            }
        }.resume()
    }
    
    // Optimized: batch Firestore fetches using "in" queries (max 10 IDs per batch per Firestore settings)
    private func loadEvents(from eventIDs: [String], completion: @escaping (Result<[Event], Error>) -> Void) {
        guard !eventIDs.isEmpty else {
            completion(.success([]))
            return
        }
        
        let chunks = stride(from: 0, to: eventIDs.count, by: 10).map {
            Array(eventIDs[$0..<min($0 + 10, eventIDs.count)])
        }
        
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
                #if DEBUG
                print("\(events.count) recommendations fetched from Firestore (batched)")
                #endif
                // Preserve original order if needed
                let mapByID = Dictionary(uniqueKeysWithValues: events.compactMap { event in
                    guard let id = event.id else { return nil }
                    return (id, event)
                })
                completion(.success(events))
            }
        }
    }
}

