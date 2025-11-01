//
//  UserEventNetworkService.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class UserEventNetworkService {
    static let shared = UserEventNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    func fetchUserEvents(completion: @escaping (Result<(events: [Event], slots: [FreeTimeSlot]), Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(
                domain: "UserEventNetworkService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]
            )))
            return
        }
        
        let group = DispatchGroup()
        var freeTimeSlots: [FreeTimeSlot] = []
        var allEvents: [Event] = []
        var fetchError: Error?
        
        // Fetch free time slots
        group.enter()
        fetchFreeTimeSlots(userId: currentUser.uid) { result in
            switch result {
            case .success(let slots):
                freeTimeSlots = slots
            case .failure(let error):
                fetchError = error
            }
            group.leave()
        }
        
        // Fetch all events
        group.enter()
        fetchEvents { result in
            switch result {
            case .success(let events):
                allEvents = events
            case .failure(let error):
                if fetchError == nil {
                    fetchError = error
                }
            }
            group.leave()
        }
        
        // Wait for both to complete
        group.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
                return
            }
            
            // Filter events based on user's free time
            let availableEvents = self.filterEvents(allEvents, forFreeTimeSlots: freeTimeSlots)
            
            print("Fetched \(availableEvents.count) available events from network")
            completion(.success((events: availableEvents, slots: freeTimeSlots)))
        }
    }
    
    private func fetchFreeTimeSlots(userId: String, completion: @escaping (Result<[FreeTimeSlot], Error>) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let preferences = data["preferences"] as? [String: Any],
                  let notifications = preferences["notifications"] as? [String: Any],
                  let slotsData = notifications["free_time_slots"] as? [[String: Any]] else {
                completion(.failure(NSError(
                    domain: "UserEventNetworkService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Free time slots not found"]
                )))
                return
            }
            
            let slots = slotsData.map { FreeTimeSlot(data: $0) }
            completion(.success(slots))
        }
    }
    
    private func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let events = documents.compactMap { EventFactory.createEvent(from: $0) }
            completion(.success(events))
        }
    }
    
    private func filterEvents(_ events: [Event], forFreeTimeSlots slots: [FreeTimeSlot]) -> [Event] {
        return events.filter { event in
            guard event.activetrue else { return false }
            
            for eventDay in event.schedule.days {
                for eventTime in event.schedule.times {
                    for slot in slots {
                        if eventDay.lowercased() == slot.day.lowercased() &&
                           isTimeInRange(eventTime: eventTime, slotStart: slot.start, slotEnd: slot.end) {
                            return true
                        }
                    }
                }
            }
            
            return false
        }
    }
    
    private func isTimeInRange(eventTime: String, slotStart: String, slotEnd: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        guard let event = formatter.date(from: eventTime),
              let start = formatter.date(from: slotStart),
              let end = formatter.date(from: slotEnd) else {
            return false
        }
        
        return event >= start && event <= end
    }
}
