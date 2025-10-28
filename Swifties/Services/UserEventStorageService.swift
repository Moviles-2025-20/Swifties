//
//  UserEventStorageService.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
//

import Foundation

class UserEventStorageService {
    static let shared = UserEventStorageService()
    
    private let databaseManager = UserEventDatabaseManager.shared
    private let userDefaults = UserDefaults.standard
    private let timestampKey = "user_events_timestamp"
    private let storageExpirationHours = 12.0 // Shorter because it depends on preferences
    
    private init() {}
    
    func saveUserEventsToStorage(_ events: [Event], freeTimeSlots: [FreeTimeSlot], userId: String) {
        // Save to SQLite
        databaseManager.saveUserEvents(events, freeTimeSlots: freeTimeSlots, userId: userId)
        
        // Save timestamp
        let key = "\(timestampKey)_\(userId)"
        userDefaults.set(Date(), forKey: key)
        userDefaults.synchronize()
        
        print("User events saved to storage: \(events.count) events, \(freeTimeSlots.count) slots")
    }
    
    func loadUserEventsFromStorage(userId: String) -> (events: [Event], slots: [FreeTimeSlot])? {
        // Check if data has expired
        let key = "\(timestampKey)_\(userId)"
        if let timestamp = userDefaults.object(forKey: key) as? Date {
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
        
        // Load from SQLite
        guard let data = databaseManager.loadUserEvents(userId: userId) else {
            print("No user events found in storage")
            return nil
        }
        
        print("User events loaded from storage: \(data.events.count) events, \(data.slots.count) slots")
        return data
    }
    
    func clearStorage(userId: String) {
        databaseManager.deleteUserEvents(userId: userId)
        let key = "\(timestampKey)_\(userId)"
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
        print("User events storage cleared for user: \(userId)")
    }
    
    func debugStorage(userId: String) {
        print("\n=== DEBUG USER EVENTS STORAGE ===")
        
        let key = "\(timestampKey)_\(userId)"
        if let timestamp = userDefaults.object(forKey: key) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("Timestamp: \(timestamp)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
        } else {
            print("No timestamp")
        }
        
        databaseManager.debugDatabase(userId: userId)
        
        print("=================================\n")
    }
    
    func getStorageInfo(userId: String) -> UserEventStorageInfo {
        let key = "\(timestampKey)_\(userId)"
        let timestamp = userDefaults.object(forKey: key) as? Date
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
