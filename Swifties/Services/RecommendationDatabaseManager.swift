//
//  RecommendationDatabaseManager.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation
import SQLite

class RecommendationDatabaseManager {
    static let shared = RecommendationDatabaseManager()
    
    private var db: Connection?
    
    // Table definition
    private let recommendationsTable = Table("recommendations")
    
    // Column definitions
    private let id = Expression<String>("id")
    private let userId = Expression<String>("user_id")
    private let eventData = Expression<String>("event_data")
    private let score = Expression<Double?>("score")
    private let position = Expression<Int>("position")
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
            
            let dbPath = "\(path)/recommendations.sqlite3"
            db = try Connection(dbPath)
            
            print("Recommendations database path: \(dbPath)")
            createTable()
            createIndexes()
        } catch {
            print("Error setting up recommendations database: \(error)")
        }
    }
    
    private func createTable() {
        guard let db = db else { return }
        
        do {
            try db.run(recommendationsTable.create(ifNotExists: true) { table in
                table.column(id)
                table.column(userId)
                table.column(eventData)
                table.column(score)
                table.column(position)
                table.column(timestamp)
                
                // Composite primary key: (user_id, id)
                // This ensures each user can have their own copy of the same event
                table.primaryKey(userId, id)
            })
            
            print("Recommendations table created successfully with composite primary key")
        } catch {
            print("Error creating recommendations table: \(error)")
        }
    }
    
    private func createIndexes() {
        guard let db = db else { return }
        
        do {
            // Index on user_id for faster user-specific queries
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_user_id ON recommendations(user_id)")
            
            // Index on timestamp for expiration checks
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_timestamp ON recommendations(timestamp)")
            
            // Composite index on user_id and position for ordered retrieval
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_user_position ON recommendations(user_id, position)")
            
            print("Recommendations indexes created successfully")
        } catch {
            print("Error creating recommendations indexes: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func saveRecommendations(_ recommendations: [Event], userId: String) {
        guard let db = db else {
            print("Database connection not available")
            return
        }
        
        do {
            try db.transaction {
                // Clear existing recommendations for this user
                try db.run(recommendationsTable.filter(self.userId == userId).delete())
                
                // Insert new recommendations with position tracking
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                
                for (index, event) in recommendations.enumerated() {
                    guard let eventId = event.id else {
                        print("⚠️ Skipping event without ID at position \(index)")
                        continue
                    }
                    
                    // Convert Event to CodableEvent
                    let codableEvent = event.toCodable()
                    let eventJSON = String(
                        data: try encoder.encode(codableEvent),
                        encoding: .utf8
                    )!
                    
                    let insert = recommendationsTable.insert(
                        id <- eventId,
                        self.userId <- userId,
                        eventData <- eventJSON,
                        score <- nil, // Can be populated if you track recommendation scores
                        position <- index,
                        timestamp <- Date()
                    )
                    
                    try db.run(insert)
                }
            }
            
            print("✅ \(recommendations.count) recommendations saved to SQLite for user \(userId)")
        } catch {
            print("❌ Error saving recommendations: \(error)")
        }
    }
    
    func loadRecommendations(userId: String) -> [Event]? {
        guard let db = db else {
            print("Database connection not available")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var events: [Event] = []
            
            // Load recommendations ordered by position
            let query = recommendationsTable
                .filter(self.userId == userId)
                .order(position.asc)
            
            for row in try db.prepare(query) {
                guard let data = row[eventData].data(using: .utf8) else {
                    print("⚠️ Failed to decode event data at position \(row[position])")
                    continue
                }
                
                do {
                    // Decode as CodableEvent and convert to Event
                    let codableEvent = try decoder.decode(CodableEvent.self, from: data)
                    let event = Event.from(codable: codableEvent)
                    events.append(event)
                } catch {
                    print("⚠️ Failed to decode event at position \(row[position]): \(error)")
                    continue
                }
            }
            
            print("✅ \(events.count) recommendations loaded from SQLite for user \(userId)")
            return events.isEmpty ? nil : events
        } catch {
            print("❌ Error loading recommendations: \(error)")
            return nil
        }
    }
    
    func deleteRecommendations(userId: String) {
        guard let db = db else { return }
        
        do {
            let deleted = try db.run(recommendationsTable.filter(self.userId == userId).delete())
            print("✅ \(deleted) recommendations deleted from SQLite for user \(userId)")
        } catch {
            print("❌ Error deleting recommendations: \(error)")
        }
    }
    
    func getRecommendationCount(userId: String) -> Int {
        guard let db = db else { return 0 }
        
        do {
            return try db.scalar(recommendationsTable.filter(self.userId == userId).count)
        } catch {
            print("❌ Error getting recommendation count: \(error)")
            return 0
        }
    }
    
    func getLastUpdateTimestamp(userId: String) -> Date? {
        guard let db = db else { return nil }
        
        do {
            let query = recommendationsTable
                .filter(self.userId == userId)
                .select(timestamp)
                .order(timestamp.desc)
            
            if let row = try db.pluck(query) {
                return row[timestamp]
            }
            return nil
        } catch {
            print("❌ Error getting recommendations timestamp: \(error)")
            return nil
        }
    }
    
    // MARK: - Migration Helper (if needed)
    
    /// Call this once if you need to migrate from old schema to new composite key schema
    func migrateToCompositeKey() {
        guard let db = db else { return }
        
        do {
            // Check if migration is needed by trying to detect old schema
            let oldTableExists = try db.scalar(
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='recommendations'"
            ) as! Int64 > 0
            
            if oldTableExists {
                print("🔄 Starting migration to composite key schema...")
                
                // Rename old table
                try db.run("ALTER TABLE recommendations RENAME TO recommendations_old")
                
                // Create new table with composite key
                createTable()
                
                // Copy data from old table (this will group by user_id automatically)
                try db.run("""
                    INSERT INTO recommendations (id, user_id, event_data, score, position, timestamp)
                    SELECT id, user_id, event_data, score, position, timestamp
                    FROM recommendations_old
                """)
                
                // Drop old table
                try db.run("DROP TABLE recommendations_old")
                
                print("✅ Migration completed successfully")
            }
        } catch {
            print("❌ Migration error: \(error)")
        }
    }
    
    // MARK: - Debug
    
    func debugDatabase(userId: String) {
        guard let db = db else {
            print("Database connection not available")
            return
        }
        
        print("\n=== DEBUG RECOMMENDATIONS DATABASE ===")
        
        do {
            let count = try db.scalar(recommendationsTable.filter(self.userId == userId).count)
            print("User ID: \(userId)")
            print("Total recommendations: \(count)")
            
            if let lastUpdate = getLastUpdateTimestamp(userId: userId) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("Last update: \(formatter.string(from: lastUpdate))")
            }
            
            // Show first 5 recommendations
            let query = recommendationsTable
                .filter(self.userId == userId)
                .order(position.asc)
                .limit(5)
            
            print("\nFirst 5 recommendations:")
            for row in try db.prepare(query) {
                guard let data = row[eventData].data(using: .utf8) else { continue }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                if let codableEvent = try? decoder.decode(CodableEvent.self, from: data) {
                    print("  Position \(row[position]): \(codableEvent.name) (ID: \(row[id]))")
                }
            }
            
            // Check total database size
            let allUsersCount = try db.scalar(recommendationsTable.count)
            print("\nTotal recommendations across all users: \(allUsersCount)")
            
        } catch {
            print("❌ Error debugging recommendations database: \(error)")
        }
        
        print("======================================\n")
    }
}
