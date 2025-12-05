//
//  EventDatabaseManager.swift
//  Swifties
//
//  Refactored to use DatabaseManager singleton
//

import Foundation
import SQLite

class EventDatabaseManager {
    static let shared = EventDatabaseManager()
    
    private let dbManager = DatabaseManager.shared
    private let threadManager = ThreadManager.shared
    
    private init() {
        // Tables are automatically created by DatabaseManager.shared
    }
    
    // MARK: - CRUD Operations
    
    /// Guarda eventos en background con completion en main thread
    func saveEvents(_ events: [Event], completion: ((Bool) -> Void)? = nil) {
        dbManager.executeTransaction { db in
            // Clear existing events
            try db.run(EventsTable.table.delete())
            
            // Insert new events
            for event in events {
                try self.insertEvent(event, in: db)
            }
            
            #if DEBUG
            print("✅ \(events.count) events saved to database")
            #endif
        } completion: { result in
            switch result {
            case .success:
                completion?(true)
            case .failure(let error):
                print("❌ Error saving events: \(error)")
                completion?(false)
            }
        }
    }
    
    private func insertEvent(_ event: Event, in db: Connection) throws {
        guard let eventId = event.id else { return }
        
        let encoder = JSONEncoder()
        
        let locationJSON = try event.location.map {
            String(data: try encoder.encode($0), encoding: .utf8)
        } ?? nil
        
        let metadataJSON = String(
            data: try encoder.encode(event.metadata),
            encoding: .utf8
        )!
        
        let scheduleJSON = String(
            data: try encoder.encode(event.schedule),
            encoding: .utf8
        )!
        
        let statsJSON = String(
            data: try encoder.encode(event.stats),
            encoding: .utf8
        )!
        
        let insert = EventsTable.table.insert(
            EventsTable.id <- eventId,
            EventsTable.activetrue <- event.activetrue,
            EventsTable.category <- event.category,
            EventsTable.created <- event.created,
            EventsTable.description <- event.description,
            EventsTable.eventType <- event.eventType,
            EventsTable.locationData <- locationJSON,
            EventsTable.metadataData <- metadataJSON,
            EventsTable.name <- event.name,
            EventsTable.scheduleData <- scheduleJSON,
            EventsTable.statsData <- statsJSON,
            EventsTable.title <- event.title,
            EventsTable.type <- event.type,
            EventsTable.weatherDependent <- event.weatherDependent,
            EventsTable.timestamp <- Date()
        )
        
        try db.run(insert)
    }
    
    /// Carga eventos en background con completion en main thread
    func loadEvents(completion: @escaping ([Event]?) -> Void) {
        dbManager.executeRead { db in
            let decoder = JSONDecoder()
            var events: [Event] = []
            
            for row in try db.prepare(EventsTable.table) {
                let locationObj: EventLocation? = try {
                    guard let locationJSON = row[EventsTable.locationData] else { return nil }
                    guard let data = locationJSON.data(using: .utf8) else { return nil }
                    return try decoder.decode(EventLocation.self, from: data)
                }()
                
                let metadataObj: EventMetadata = try {
                    let data = row[EventsTable.metadataData].data(using: .utf8)!
                    return try decoder.decode(EventMetadata.self, from: data)
                }()
                
                let scheduleObj: EventSchedule = try {
                    let data = row[EventsTable.scheduleData].data(using: .utf8)!
                    return try decoder.decode(EventSchedule.self, from: data)
                }()
                
                let statsObj: EventStats = try {
                    let data = row[EventsTable.statsData].data(using: .utf8)!
                    return try decoder.decode(EventStats.self, from: data)
                }()
                
                let event = Event(
                    id: row[EventsTable.id],
                    activetrue: row[EventsTable.activetrue],
                    category: row[EventsTable.category],
                    created: row[EventsTable.created],
                    description: row[EventsTable.description],
                    eventType: row[EventsTable.eventType],
                    location: locationObj,
                    metadata: metadataObj,
                    name: row[EventsTable.name],
                    schedule: scheduleObj,
                    stats: statsObj,
                    title: row[EventsTable.title],
                    type: row[EventsTable.type],
                    weatherDependent: row[EventsTable.weatherDependent]
                )
                
                events.append(event)
            }
            
            #if DEBUG
            print("✅ \(events.count) events loaded from database")
            #endif
            
            return events
        } completion: { result in
            switch result {
            case .success(let events):
                completion(events.isEmpty ? nil : events)
            case .failure(let error):
                print("❌ Error loading events: \(error)")
                completion(nil)
            }
        }
    }
    
    func deleteAllEvents(completion: ((Bool) -> Void)? = nil) {
        dbManager.executeWrite { db in
            try db.run(EventsTable.table.delete())
            #if DEBUG
            print("✅ All events deleted")
            #endif
        } completion: { result in
            switch result {
            case .success:
                completion?(true)
            case .failure(let error):
                print("❌ Error deleting events: \(error)")
                completion?(false)
            }
        }
    }
    
    func getEventCount(completion: @escaping (Int) -> Void) {
        dbManager.executeRead { db in
            try db.scalar(EventsTable.table.count)
        } completion: { result in
            switch result {
            case .success(let count):
                completion(count)
            case .failure:
                completion(0)
            }
        }
    }
    
    func getLastUpdateTimestamp(completion: @escaping (Date?) -> Void) {
        dbManager.executeRead { db in
            if let row = try db.pluck(
                EventsTable.table
                    .select(EventsTable.timestamp)
                    .order(EventsTable.timestamp.desc)
            ) {
                return row[EventsTable.timestamp]
            }
            return nil
        } completion: { result in
            completion((try? result.get()) ?? nil)
        }
    }
    
    // MARK: - Query Methods
    
    /// Filters events by category
    func getEventsByCategory(_ category: String, completion: @escaping ([Event]?) -> Void) {
        dbManager.executeRead { db in
            let query = EventsTable.table.filter(EventsTable.category == category)
            var events: [Event] = []
            
            let decoder = JSONDecoder()
            
            for row in try db.prepare(query) {
                let locationObj: EventLocation? = try {
                    guard let locationJSON = row[EventsTable.locationData] else { return nil }
                    guard let data = locationJSON.data(using: .utf8) else { return nil }
                    return try decoder.decode(EventLocation.self, from: data)
                }()
                
                let metadataObj: EventMetadata = try {
                    let data = row[EventsTable.metadataData].data(using: .utf8)!
                    return try decoder.decode(EventMetadata.self, from: data)
                }()
                
                let scheduleObj: EventSchedule = try {
                    let data = row[EventsTable.scheduleData].data(using: .utf8)!
                    return try decoder.decode(EventSchedule.self, from: data)
                }()
                
                let statsObj: EventStats = try {
                    let data = row[EventsTable.statsData].data(using: .utf8)!
                    return try decoder.decode(EventStats.self, from: data)
                }()
                
                let event = Event(
                    id: row[EventsTable.id],
                    activetrue: row[EventsTable.activetrue],
                    category: row[EventsTable.category],
                    created: row[EventsTable.created],
                    description: row[EventsTable.description],
                    eventType: row[EventsTable.eventType],
                    location: locationObj,
                    metadata: metadataObj,
                    name: row[EventsTable.name],
                    schedule: scheduleObj,
                    stats: statsObj,
                    title: row[EventsTable.title],
                    type: row[EventsTable.type],
                    weatherDependent: row[EventsTable.weatherDependent]
                )
                
                events.append(event)
            }
            
            return events
        } completion: { result in
            completion((try? result.get()) ?? nil)
        }
    }
    
    // MARK: - Debug
    
    func debugDatabase() {
        dbManager.executeRead { db in
            let count = try db.scalar(EventsTable.table.count)
            print("\n=== DEBUG EVENTS TABLE ===")
            print("Total events: \(count)")
            
            if let row = try db.pluck(
                EventsTable.table
                    .select(EventsTable.timestamp)
                    .order(EventsTable.timestamp.desc)
            ) {
                print("Last update: \(row[EventsTable.timestamp])")
            }
            
            let query = EventsTable.table.limit(3)
            for row in try db.prepare(query) {
                print("Event: \(row[EventsTable.name]) - Category: \(row[EventsTable.category])")
            }
            
            print("==========================\n")
        } completion: { _ in }
    }
}
