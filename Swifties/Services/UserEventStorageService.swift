//
//  UserEventStorageService.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
//

import Foundation

class UserEventStorageService {
    static let shared = UserEventStorageService()
    
    private let userDefaults = UserDefaults.standard
    private let eventsKey = "user_events"
    private let slotsKey = "user_free_time_slots"
    private let timestampKey = "user_events_timestamp"
    private let storageExpirationHours = 12.0 // Shorter because it depends on preferences
    
    private init() {}
    
    func saveUserEventsToStorage(_ events: [Event], freeTimeSlots: [FreeTimeSlot], userId: String) {
        // Convert to Codable
        let codableEvents = events.map { $0.toCodable() }
        let codableSlots = freeTimeSlots.map { CodableFreeTimeSlot(from: $0) }
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let eventsData = try encoder.encode(codableEvents)
            let slotsData = try encoder.encode(codableSlots)
            
            // Save with userId prefix
            let eventsKey = "\(self.eventsKey)_\(userId)"
            let slotsKey = "\(self.slotsKey)_\(userId)"
            let timestampKey = "\(self.timestampKey)_\(userId)"
            
            userDefaults.set(eventsData, forKey: eventsKey)
            userDefaults.set(slotsData, forKey: slotsKey)
            userDefaults.set(Date(), forKey: timestampKey)
            userDefaults.synchronize()
            
            print("User events saved to UserDefaults: \(events.count) events, \(freeTimeSlots.count) slots")
        } catch {
            print("Error encoding user events: \(error.localizedDescription)")
        }
    }
    
    func loadUserEventsFromStorage(userId: String) -> (events: [Event], slots: [FreeTimeSlot])? {
        // Check if data has expired
        let timestampKey = "\(self.timestampKey)_\(userId)"
        if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("User events storage age: \(String(format: "%.1f", hoursElapsed)) hours")
            
            if hoursElapsed > storageExpirationHours {
                clearStorage(userId: userId)
                return nil
            }
        } else {
            print("No timestamp found for user events")
            return nil
        }
        
        // Load from UserDefaults
        let eventsKey = "\(self.eventsKey)_\(userId)"
        let slotsKey = "\(self.slotsKey)_\(userId)"
        
        guard let eventsData = userDefaults.data(forKey: eventsKey),
              let slotsData = userDefaults.data(forKey: slotsKey) else {
            print("No user events found in UserDefaults")
            return nil
        }
        
        // Decode from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableEvents = try decoder.decode([CodableEvent].self, from: eventsData)
            let codableSlots = try decoder.decode([CodableFreeTimeSlot].self, from: slotsData)
            
            let events = codableEvents.map { Event.from(codable: $0) }
            let slots = codableSlots.map { $0.toFreeTimeSlot() }
            
            print("User events loaded from UserDefaults: \(events.count) events, \(slots.count) slots")
            return (events: events, slots: slots)
        } catch {
            print("Error decoding user events: \(error.localizedDescription)")
            clearStorage(userId: userId)
            return nil
        }
    }
    
    func clearStorage(userId: String) {
        let eventsKey = "\(self.eventsKey)_\(userId)"
        let slotsKey = "\(self.slotsKey)_\(userId)"
        let timestampKey = "\(self.timestampKey)_\(userId)"
        
        userDefaults.removeObject(forKey: eventsKey)
        userDefaults.removeObject(forKey: slotsKey)
        userDefaults.removeObject(forKey: timestampKey)
        userDefaults.synchronize()
        
        print("User events storage cleared for user: \(userId)")
    }
    
    func debugStorage(userId: String) {
        print("\n=== DEBUG USER EVENTS STORAGE (UserDefaults) ===")
        
        let timestampKey = "\(self.timestampKey)_\(userId)"
        if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("Timestamp: \(timestamp)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
        } else {
            print("No timestamp")
        }
        
        let eventsKey = "\(self.eventsKey)_\(userId)"
        let slotsKey = "\(self.slotsKey)_\(userId)"
        
        if let eventsData = userDefaults.data(forKey: eventsKey),
           let slotsData = userDefaults.data(forKey: slotsKey) {
            print("Events data size: \(eventsData.count) bytes")
            print("Slots data size: \(slotsData.count) bytes")
            
            let decoder = JSONDecoder()
            if let events = try? decoder.decode([CodableEvent].self, from: eventsData),
               let slots = try? decoder.decode([CodableFreeTimeSlot].self, from: slotsData) {
                print("Events count: \(events.count)")
                print("Slots count: \(slots.count)")
            }
        } else {
            print("No data found in UserDefaults")
        }
        
        print("=================================================\n")
    }
    
    func getStorageInfo(userId: String) -> UserEventStorageInfo {
        let timestampKey = "\(self.timestampKey)_\(userId)"
        let timestamp = userDefaults.object(forKey: timestampKey) as? Date
        let isExpired: Bool
        
        if let timestamp = timestamp {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            isExpired = hoursElapsed > storageExpirationHours
        } else {
            isExpired = true
        }
        
        return UserEventStorageInfo(
            lastUpdate: timestamp,
            isExpired: isExpired
        )
    }
    
    func getStorageSize(userId: String) -> Int {
        let eventsKey = "\(self.eventsKey)_\(userId)"
        let slotsKey = "\(self.slotsKey)_\(userId)"
        
        var totalSize = 0
        
        if let eventsData = userDefaults.data(forKey: eventsKey) {
            totalSize += eventsData.count
        }
        
        if let slotsData = userDefaults.data(forKey: slotsKey) {
            totalSize += slotsData.count
        }
        
        return totalSize
    }
}

// MARK: - Storage Info Model

struct UserEventStorageInfo {
    let lastUpdate: Date?
    let isExpired: Bool
    
    var ageInHours: Double? {
        guard let lastUpdate = lastUpdate else { return nil }
        return Date().timeIntervalSince(lastUpdate) / 3600
    }
}

// MARK: - Codable FreeTimeSlot

struct CodableFreeTimeSlot: Codable {
    let id: String
    let day: String
    let start: String
    let end: String
    
    init(from slot: FreeTimeSlot) {
        self.id = slot.id
        self.day = slot.day
        self.start = slot.start
        self.end = slot.end
    }
    
    func toFreeTimeSlot() -> FreeTimeSlot {
        FreeTimeSlot(id: id, day: day, start: start, end: end)
    }
}
