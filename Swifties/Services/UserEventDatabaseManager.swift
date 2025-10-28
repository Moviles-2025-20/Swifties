import Foundation
import SQLite

class UserEventDatabaseManager {
    static let shared = UserEventDatabaseManager()
    
    private var db: Connection?
    
    // Tables
    private let userEventsTable = Table("user_available_events")
    private let freeTimeSlotsTable = Table("user_free_time_slots")
    
    // user_available_events columns
    private let eventId = Expression<String>("event_id")
    private let eventData = Expression<String>("event_data")
    private let userId = Expression<String>("user_id")
    private let timestamp = Expression<Date>("timestamp")
    
    // user_free_time_slots columns
    private let slotId = Expression<String>("slot_id")
    private let day = Expression<String>("day")
    private let start = Expression<String>("start")
    private let end = Expression<String>("end")
    private let slotUserId = Expression<String>("user_id")
    private let slotTimestamp = Expression<Date>("timestamp")
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            
            let dbPath = "\(path)/user_events.sqlite3"
            db = try Connection(dbPath)
            
            print("User events database path: \(dbPath)")
            createTables()
            createIndexes()
        } catch {
            print("Error setting up user events database: \(error)")
        }
    }
    
    private func createTables() {
        guard let db = db else { return }
        
        do {
            // User available events table
            try db.run(userEventsTable.create(ifNotExists: true) { table in
                table.column(eventId, primaryKey: true)
                table.column(eventData)
                table.column(userId)
                table.column(timestamp)
            })
            
            // Free time slots table
            try db.run(freeTimeSlotsTable.create(ifNotExists: true) { table in
                table.column(slotId, primaryKey: true)
                table.column(day)
                table.column(start)
                table.column(end)
                table.column(slotUserId)
                table.column(slotTimestamp)
            })
            
            print("User events tables created successfully")
        } catch {
            print("Error creating user events tables: \(error)")
        }
    }
    
    private func createIndexes() {
        guard let db = db else { return }
        
        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_user_events_user_id ON user_available_events(user_id)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_user_events_timestamp ON user_available_events(timestamp)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_free_slots_user_id ON user_free_time_slots(user_id)")
            print("User events indexes created successfully")
        } catch {
            print("Error creating user events indexes: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func saveUserEvents(_ events: [Event], freeTimeSlots: [FreeTimeSlot], userId: String) {
        guard let db = db else {
            print("Database connection not available")
            return
        }
        
        do {
            try db.transaction {
                // Clear existing user data
                try db.run(userEventsTable.filter(self.userId == userId).delete())
                try db.run(freeTimeSlotsTable.filter(self.slotUserId == userId).delete())
                
                // Insert events - CONVERT TO CODABLE
                let encoder = JSONEncoder()
                for event in events {
                    guard let eventIdValue = event.id else { continue }
                    
                    // Convertir Event a CodableEvent
                    let codableEvent = event.toCodable()
                    let eventJSON = String(
                        data: try encoder.encode(codableEvent),
                        encoding: .utf8
                    )!
                    
                    let insert = userEventsTable.insert(
                        eventId <- eventIdValue,
                        eventData <- eventJSON,
                        self.userId <- userId,
                        timestamp <- Date()
                    )
                    
                    try db.run(insert)
                }
                
                // Insert free time slots
                for slot in freeTimeSlots {
                    let insert = freeTimeSlotsTable.insert(
                        slotId <- slot.id,
                        day <- slot.day,
                        start <- slot.start,
                        end <- slot.end,
                        slotUserId <- userId,
                        slotTimestamp <- Date()
                    )
                    try db.run(insert)
                }
            }
            
            print("Saved \(events.count) user events and \(freeTimeSlots.count) slots to SQLite")
        } catch {
            print("Error saving user events: \(error)")
        }
    }
    
    func loadUserEvents(userId: String) -> (events: [Event], slots: [FreeTimeSlot])? {
        guard let db = db else {
            print("Database connection not available")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            var events: [Event] = []
            var slots: [FreeTimeSlot] = []
            
            // Load events - DECODIFICAR COMO CODABLE
            let eventsQuery = userEventsTable.filter(self.userId == userId)
            for row in try db.prepare(eventsQuery) {
                guard let data = row[eventData].data(using: .utf8) else { continue }
                // Decodificar como CodableEvent y convertir a Event
                let codableEvent = try decoder.decode(CodableEvent.self, from: data)
                let event = Event.from(codable: codableEvent)
                events.append(event)
            }
            
            // Load free time slots - CORREGIDO: UN SOLO BUCLE
            let slotsQuery = freeTimeSlotsTable.filter(slotUserId == userId)
            for row in try db.prepare(slotsQuery) {
                let slot = FreeTimeSlot(
                    id: row[slotId],
                    day: row[day],
                    start: row[start],
                    end: row[end]
                )
                slots.append(slot)
            }
            
            print("Loaded \(events.count) user events and \(slots.count) slots from SQLite")
            return events.isEmpty && slots.isEmpty ? nil : (events, slots)
        } catch {
            print("Error loading user events: \(error)")
            return nil
        }
    }
    
    func deleteUserEvents(userId: String) {
        guard let db = db else { return }
        
        do {
            try db.run(userEventsTable.filter(self.userId == userId).delete())
            try db.run(freeTimeSlotsTable.filter(slotUserId == userId).delete())
            print("User events deleted from SQLite for user: \(userId)")
        } catch {
            print("Error deleting user events: \(error)")
        }
    }
    
    func getLastUpdateTimestamp(userId: String) -> Date? {
        guard let db = db else { return nil }
        
        do {
            let query = userEventsTable
                .filter(self.userId == userId)
                .select(timestamp)
                .order(timestamp.desc)
            
            if let row = try db.pluck(query) {
                return row[timestamp]
            }
            return nil
        } catch {
            print("Error getting user events timestamp: \(error)")
            return nil
        }
    }
    
    // MARK: - Debug
    
    func debugDatabase(userId: String) {
        guard let db = db else {
            print("Database connection not available")
            return
        }
        
        print("\n=== DEBUG USER EVENTS DATABASE ===")
        
        do {
            let eventsCount = try db.scalar(userEventsTable.filter(self.userId == userId).count)
            let slotsCount = try db.scalar(freeTimeSlotsTable.filter(slotUserId == userId).count)
            
            print("User ID: \(userId)")
            print("Available events: \(eventsCount)")
            print("Free time slots: \(slotsCount)")
            
            if let lastUpdate = getLastUpdateTimestamp(userId: userId) {
                print("Last update: \(lastUpdate)")
            }
        } catch {
            print("Error debugging user events database: \(error)")
        }
        
        print("==================================\n")
    }
}
