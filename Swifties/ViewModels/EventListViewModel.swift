//
//  EventListViewModel.swift
//  Swifties
//
//  Created by Imac on 1/10/25.
//

import Foundation
import FirebaseFirestore
import Combine

class EventListViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let db = Firestore.firestore(database: "default")

    init() {
        // Initialize Firestore and configure settings
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true // optional offline cache
        firestore.settings = settings
    }

    func loadEvents() {
        isLoading = true
        errorMessage = nil

        db.collection("events").getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Error loading events: \(error.localizedDescription)"
                    print(self.errorMessage ?? "")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No events found"
                    return
                }

                // Parse documents with complete data
                self.events = documents.compactMap { doc in
                    self.parseEvent(documentId: doc.documentID, data: doc.data())
                }

                print("Events loaded: \(self.events.count)")
            }
        }
    }
    
    func parseEvent(documentId: String, data: [String: Any]) -> Event? {
        // Required fields
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String else {
            print("Incomplete document: \(documentId)")
            return nil
        }
        
        // Location parsing
        var location = EventLocation(address: "", city: "", coordinates: [], type: "")
        if let locationData = data["location"] as? [String: Any] {
            location = EventLocation(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                coordinates: locationData["coordinates"] as? [Double] ?? [],
                type: locationData["type"] as? String ?? ""
            )
        }
        
        // Schedule parsing
        var schedule = EventSchedule(days: [], times: [])
        if let scheduleData = data["schedule"] as? [String: Any] {
            schedule = EventSchedule(
                days: scheduleData["days"] as? [String] ?? [],
                times: scheduleData["times"] as? [String] ?? []
            )
        }
        
        // Metadata parsing
        var metadata = EventMetadata(
            cost: EventCost(amount: 0, currency: "COP"),
            durationMinutes: 0,
            imageUrl: "",
            tags: []
        )
        if let metadataData = data["metadata"] as? [String: Any] {
            var cost = EventCost(amount: 0, currency: "COP")
            if let costData = metadataData["cost"] as? [String: Any] {
                let amount = costData["amount"] as? Int ?? 0
                let currency = costData["currency"] as? String ?? "COP"
                cost = EventCost(amount: amount, currency: currency)
            }
            
            metadata = EventMetadata(
                cost: cost,
                durationMinutes: metadataData["duration_minutes"] as? Int ?? 0,
                imageUrl: metadataData["image_url"] as? String ?? "",
                tags: metadataData["tags"] as? [String] ?? []
            )
        }
        
        // Stats parsing
        var stats = EventStats(popularity: 0, rating: 0, totalCompletions: 0)
        if let statsData = data["stats"] as? [String: Any] {
            stats = EventStats(
                popularity: statsData["popularity"] as? Int ?? 0,
                rating: statsData["rating"] as? Int ?? 0,
                totalCompletions: statsData["total_completions"] as? Int ?? 0
            )
        }
        
        return Event(
            activetrue: data["active"] as? Bool ?? true,
            category: category,
            created: data["created"] as? String ?? "",
            description: description,
            eventType: data["event_type"] as? String ?? "",
            location: location,
            metadata: metadata,
            name: name,
            schedule: schedule,
            stats: stats,
            title: data["title"] as? String ?? "",
            type: data["type"] as? String ?? "",
            weatherDependent: data["weather_dependent"] as? Bool ?? false
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
