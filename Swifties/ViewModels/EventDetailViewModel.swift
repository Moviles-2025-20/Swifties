//
//  EventDetailViewModel.swift
//  Swifties
//
//

import Foundation
import FirebaseFirestore
import Combine

class EventDetailViewModel: ObservableObject {
    @Published var event: Event?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let eventId: String
    let db = Firestore.firestore(database: "default")
    
    init(eventId: String) {
        self.eventId = eventId
        
        // Configure Firestore settings
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true
        firestore.settings = settings
    }
    
    func loadEventDetail() {
        guard !eventId.isEmpty else {
            errorMessage = "Invalid event ID"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("events").document(eventId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error loading event: \(error.localizedDescription)"
                    print(self.errorMessage ?? "")
                    return
                }
                
                guard let document = document, document.exists else {
                    self.errorMessage = "Event not found"
                    return
                }
                
                // Parse the event from document data
                let data = document.data() ?? [:]
                self.event = self.parseEvent(documentId: document.documentID, data: data)
                
                if self.event == nil {
                    self.errorMessage = "Error parsing event data"
                } else {
                    print("Event loaded successfully: \(self.event?.name ?? "")")
                }
            }
        }
    }
    
    private func parseEvent(documentId: String, data: [String: Any]) -> Event? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String else {
            print("Missing required fields")
            return nil
        }
        
        // Location parsing
        var location = Event.Location(city: "", type: "", address: "", coordinates: [])
        if let locationData = data["location"] as? [String: Any] {
            location = Event.Location(
                city: locationData["city"] as? String ?? "",
                type: locationData["type"] as? String ?? "",
                address: locationData["address"] as? String ?? "",
                coordinates: locationData["coordinates"] as? [Double] ?? []
            )
        }
        
        // Schedule parsing
        var schedule = Event.Schedule(days: [], times: [])
        if let scheduleData = data["schedule"] as? [String: Any] {
            schedule = Event.Schedule(
                days: scheduleData["days"] as? [String] ?? [],
                times: scheduleData["times"] as? [String] ?? []
            )
        }
        
        // Metadata parsing
        var metadata: Event.Metadata?
        if let metadataData = data["metadata"] as? [String: Any] {
            var cost = Event.Cost(amount: 0, currency: "FREE")
            if let costData = metadataData["cost"] as? [String: Any] {
                let amount = costData["amount"] as? Int ?? 0
                let currency = costData["currency"] as? String ?? "COP"
                cost = Event.Cost(amount: amount, currency: currency)
            }
            
            metadata = Event.Metadata(
                imageUrl: metadataData["image_url"] as? String ?? "",
                tags: metadataData["tags"] as? [String] ?? [],
                durationMinutes: metadataData["duration_minutes"] as? Int ?? 0,
                cost: cost
            )
        }
        
        // Stats parsing
        var stats: Event.EventStats?
        if let statsData = data["stats"] as? [String: Any] {
            stats = Event.EventStats(
                popularity: statsData["popularity"] as? Int ?? 0,
                totalCompletions: statsData["total_completions"] as? Int ?? 0,
                rating: statsData["rating"] as? Double ?? 0.0
            )
        }
        
        return Event(
            id: documentId,
            title: data["title"] as? String,
            name: name,
            description: description,
            type: data["type"] as? String,
            category: category,
            active: data["active"] as? Bool ?? true,
            eventType: data["event_type"] as? String,
            location: location,
            schedule: schedule,
            metadata: metadata,
            stats: stats,
            weatherDependent: data["weather_dependent"] as? Bool ?? false,
            created: data["created"] as? Timestamp
        )
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

