//
//  UserInfoViewModel.swift
//  Swifties
//
//  Created
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class UserInfoViewModel: ObservableObject {
    @Published var freeTimeSlots: [FreeTimeSlot] = []
    @Published var availableEvents: [Event] = []
    @Published var allEvents: [Event] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore(database: "default")
    
    // MARK: - Load Data
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        let group = DispatchGroup()
        
        // Load free time slots
        group.enter()
        fetchFreeTimeSlots { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let slots):
                    self.freeTimeSlots = slots
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
            group.leave()
        }
        
        // Load all events
        group.enter()
        fetchEvents { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let events):
                    self.allEvents = events
                case .failure(let error):
                    if self.errorMessage == nil {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
            group.leave()
        }
        
        // After both complete, filter events
        group.notify(queue: .main) {
            self.filterAvailableEvents()
            self.isLoading = false
        }
    }
    
    // MARK: - Fetch Free Time Slots
    private func fetchFreeTimeSlots(completion: @escaping (Result<[FreeTimeSlot], Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            completion(.failure(error))
            return
        }
        
        let userRef = db.collection("users").document(currentUser.uid)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let preferences = data["preferences"] as? [String: Any],
                  let notifications = preferences["notifications"] as? [String: Any],
                  let slotsData = notifications["free_time_slots"] as? [[String: Any]] else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Free time slots not found"])
                completion(.failure(error))
                return
            }
            
            let slots = slotsData.map { FreeTimeSlot(data: $0) }
            completion(.success(slots))
        }
    }
    
    // MARK: - Fetch Events
    
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
    

    
    // MARK: - Filter Available Events
    private func filterAvailableEvents() {
        availableEvents = allEvents.filter { event in
            // Check if event is active
            guard event.activetrue else { return false }
            
            // Check if any event day/time matches user's free time
            for eventDay in event.schedule.days {
                for eventTime in event.schedule.times {
                    for slot in freeTimeSlots {
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
    
    // MARK: - Check if Time is in Range
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
