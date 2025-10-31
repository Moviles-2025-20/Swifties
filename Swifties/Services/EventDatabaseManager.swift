//
//  EventDatabaseManager.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
//  Modified with multithreading support
//

import Foundation
import SQLite

class EventDatabaseManager {
    static let shared = EventDatabaseManager()
    
    private var db: Connection?
    private let threadManager = ThreadManager.shared
    
    // Table definition
    private let eventsTable = Table("events")
    
    // Column definitions
    private let id = Expression<String>("id")
    private let activetrue = Expression<Bool>("activetrue")
    private let category = Expression<String>("category")
    private let created = Expression<String>("created")
    private let description = Expression<String>("description")
    private let eventType = Expression<String>("event_type")
    private let locationData = Expression<String?>("location_data")
    private let metadataData = Expression<String>("metadata_data")
    private let name = Expression<String>("name")
    private let scheduleData = Expression<String>("schedule_data")
    private let statsData = Expression<String>("stats_data")
    private let title = Expression<String>("title")
    private let type = Expression<String>("type")
    private let weatherDependent = Expression<Bool>("weather_dependent")
    private let timestamp = Expression<Date>("timestamp")
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            
            let dbPath = "\(path)/events.sqlite3"
            db = try Connection(dbPath)
            
            print("Database path: \(dbPath)")
            createTable()
            createIndexes()
        } catch {
            print("Error setting up database: \(error)")
        }
    }
    
    private func createTable() {
        guard let db = db else { return }
        
        do {
            try db.run(eventsTable.create(ifNotExists: true) { table in
                table.column(id, primaryKey: true)
                table.column(activetrue)
                table.column(category)
                table.column(created)
                table.column(description)
                table.column(eventType)
                table.column(locationData)
                table.column(metadataData)
                table.column(name)
                table.column(scheduleData)
                table.column(statsData)
                table.column(title)
                table.column(type)
                table.column(weatherDependent)
                table.column(timestamp)
            })
            
            print("Events table created successfully")
        } catch {
            print("Error creating table: \(error)")
        }
    }
    
    private func createIndexes() {
        guard let db = db else { return }
        
        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_category ON events(category)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_event_type ON events(event_type)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_timestamp ON events(timestamp)")
            print("Indexes created successfully")
        } catch {
            print("rror creating indexes: \(error)")
        }
    }
    
    // MARK: - CRUD Operations (Threaded)
    
    /// Guarda eventos en background con completion en main thread
    func saveEvents(_ events: [Event], completion: ((Bool) -> Void)? = nil) {
        threadManager.executeDatabaseOperation {
            guard let db = self.db else {
                print("Database connection not available")
                self.threadManager.executeOnMain {
                    completion?(false)
                }
                return
            }
            
            do {
                try db.transaction {
                    // Clear existing events
                    try db.run(self.eventsTable.delete())
                    
                    // Insert new events
                    for event in events {
                        try self.insertEvent(event)
                    }
                }
                
                print("\(events.count) events saved to SQLite (background thread)")
                
                self.threadManager.executeOnMain {
                    completion?(true)
                }
            } catch {
                print("Error saving events: \(error)")
                self.threadManager.executeOnMain {
                    completion?(false)
                }
            }
        }
    }
    
    private func insertEvent(_ event: Event) throws {
        guard let db = db, let eventId = event.id else { return }
        
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
        
        let insert = eventsTable.insert(
            id <- eventId,
            activetrue <- event.activetrue,
            category <- event.category,
            created <- event.created,
            description <- event.description,
            eventType <- event.eventType,
            locationData <- locationJSON,
            metadataData <- metadataJSON,
            name <- event.name,
            scheduleData <- scheduleJSON,
            statsData <- statsJSON,
            title <- event.title,
            type <- event.type,
            weatherDependent <- event.weatherDependent,
            timestamp <- Date()
        )
        
        try db.run(insert)
    }
    
    /// Carga eventos en background con completion en main thread
    func loadEvents(completion: @escaping ([Event]?) -> Void) {
        threadManager.executeDatabaseOperation {
            guard let db = self.db else {
                print("Database connection not available")
                self.threadManager.executeOnMain {
                    completion(nil)
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                var events: [Event] = []
                
                for row in try db.prepare(self.eventsTable) {
                    let locationObj: EventLocation? = try {
                        guard let locationJSON = row[self.locationData] else { return nil }
                        guard let data = locationJSON.data(using: .utf8) else { return nil }
                        return try decoder.decode(EventLocation.self, from: data)
                    }()
                    
                    let metadataObj: EventMetadata = try {
                        let data = row[self.metadataData].data(using: .utf8)!
                        return try decoder.decode(EventMetadata.self, from: data)
                    }()
                    
                    let scheduleObj: EventSchedule = try {
                        let data = row[self.scheduleData].data(using: .utf8)!
                        return try decoder.decode(EventSchedule.self, from: data)
                    }()
                    
                    let statsObj: EventStats = try {
                        let data = row[self.statsData].data(using: .utf8)!
                        return try decoder.decode(EventStats.self, from: data)
                    }()
                    
                    let event = Event(
                        id: row[self.id],
                        activetrue: row[self.activetrue],
                        category: row[self.category],
                        created: row[self.created],
                        description: row[self.description],
                        eventType: row[self.eventType],
                        location: locationObj,
                        metadata: metadataObj,
                        name: row[self.name],
                        schedule: scheduleObj,
                        stats: statsObj,
                        title: row[self.title],
                        type: row[self.type],
                        weatherDependent: row[self.weatherDependent]
                    )
                    
                    events.append(event)
                }
                
                print("\(events.count) events loaded from SQLite (background thread)")
                
                self.threadManager.executeOnMain {
                    completion(events.isEmpty ? nil : events)
                }
            } catch {
                print("Error loading events: \(error)")
                self.threadManager.executeOnMain {
                    completion(nil)
                }
            }
        }
    }
    
    func deleteAllEvents(completion: ((Bool) -> Void)? = nil) {
        threadManager.executeDatabaseOperation {
            guard let db = self.db else {
                self.threadManager.executeOnMain {
                    completion?(false)
                }
                return
            }
            
            do {
                try db.run(self.eventsTable.delete())
                print("All events deleted from SQLite")
                self.threadManager.executeOnMain {
                    completion?(true)
                }
            } catch {
                print("Error deleting events: \(error)")
                self.threadManager.executeOnMain {
                    completion?(false)
                }
            }
        }
    }
    
    func getEventCount(completion: @escaping (Int) -> Void) {
        threadManager.executeDatabaseOperation {
            guard let db = self.db else {
                self.threadManager.executeOnMain {
                    completion(0)
                }
                return
            }
            
            do {
                let count = try db.scalar(self.eventsTable.count)
                self.threadManager.executeOnMain {
                    completion(count)
                }
            } catch {
                print("Error getting event count: \(error)")
                self.threadManager.executeOnMain {
                    completion(0)
                }
            }
        }
    }
    
    func getLastUpdateTimestamp(completion: @escaping (Date?) -> Void) {
        threadManager.executeDatabaseOperation {
            guard let db = self.db else {
                self.threadManager.executeOnMain {
                    completion(nil)
                }
                return
            }
            
            do {
                if let row = try db.pluck(self.eventsTable.select(self.timestamp).order(self.timestamp.desc)) {
                    let date = row[self.timestamp]
                    self.threadManager.executeOnMain {
                        completion(date)
                    }
                } else {
                    self.threadManager.executeOnMain {
                        completion(nil)
                    }
                }
            } catch {
                print("Error getting timestamp: \(error)")
                self.threadManager.executeOnMain {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Debug
    
    func debugDatabase() {
        threadManager.executeDatabaseOperation {
            guard let db = self.db else {
                print("Database connection not available")
                return
            }
            
            print("\n=== DEBUG SQLite DATABASE ===")
            
            do {
                let count = try db.scalar(self.eventsTable.count)
                print("Total events: \(count)")
                
                if let row = try db.pluck(self.eventsTable.select(self.timestamp).order(self.timestamp.desc)) {
                    print("Last update: \(row[self.timestamp])")
                }
                
                let query = self.eventsTable.limit(3)
                for row in try db.prepare(query) {
                    print("Event: \(row[self.name]) - Category: \(row[self.category])")
                }
            } catch {
                print("Error debugging database: \(error)")
            }
            
            print("============================\n")
        }
    }
}
