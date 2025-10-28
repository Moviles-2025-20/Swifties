//
//  EventStorageService.swift
//  Swifties
//
//  Created by Imac  on 26/10/25.
//

import Foundation

class EventStorageService {
    static let shared = EventStorageService()
    
    private let databaseManager = EventDatabaseManager.shared
    private let userDefaults = UserDefaults.standard
    private let timestampKey = "cached_events_timestamp"
    private let storageExpirationHours = 24.0
    
    private init() {}
    
    func saveEventsToStorage(_ events: [Event]) {
        // Save events to SQLite
        databaseManager.saveEvents(events)
        
        // Save timestamp to UserDefaults
        userDefaults.set(Date(), forKey: timestampKey)
        userDefaults.synchronize()
        
        print("\(events.count) events saved to SQLite storage")
    }
    
    func loadEventsFromStorage() -> [Event]? {
        // Check if data has expired
        if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("Storage age: \(String(format: "%.1f", hoursElapsed)) hours")
            
            if hoursElapsed > storageExpirationHours {
                clearStorage()
                return nil
            }
        } else {
            print("No timestamp found in storage")
            return nil
        }
        
        // Load events from SQLite
        guard let events = databaseManager.loadEvents() else {
            print("No events found in SQLite storage")
            return nil
        }
        
        print("\(events.count) events loaded from SQLite storage")
        return events
    }
    
    func clearStorage() {
        databaseManager.deleteAllEvents()
        userDefaults.removeObject(forKey: timestampKey)
        userDefaults.synchronize()
        print("SQLite storage cleared")
    }
    
    func debugStorage() {
        print("\n=== DEBUG STORAGE ===")
        
        // Check timestamp
        if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("Timestamp: \(timestamp)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
        } else {
            print("No timestamp")
        }
        
        // Check database
        let count = databaseManager.getEventCount()
        print("Events in database: \(count)")
        
        if let lastUpdate = databaseManager.getLastUpdateTimestamp() {
            print("Last database update: \(lastUpdate)")
        }
        
        print("===================\n")
        
        // Detailed database debug
        databaseManager.debugDatabase()
    }
    
    // MARK: - Additional helpers
    
    func getStorageInfo() -> StorageInfo {
        let count = databaseManager.getEventCount()
        let timestamp = userDefaults.object(forKey: timestampKey) as? Date
        let isExpired: Bool
        
        if let timestamp = timestamp {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            isExpired = hoursElapsed > storageExpirationHours
        } else {
            isExpired = true
        }
        
        return StorageInfo(
            eventCount: count,
            lastUpdate: timestamp,
            isExpired: isExpired
        )
    }
}

// MARK: - Storage Info Model

struct StorageInfo {
    let eventCount: Int
    let lastUpdate: Date?
    let isExpired: Bool
    
    var ageInHours: Double? {
        guard let lastUpdate = lastUpdate else { return nil }
        return Date().timeIntervalSince(lastUpdate) / 3600
    }
}
