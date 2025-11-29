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
    // Store timestamp as Int64 (Unix seconds) to be compatible with SQLite.Binding
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
            
            #if DEBUG
            print("Recommendations database path: \(dbPath)")
            #endif
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
                table.column(position)
                table.column(timestamp)
                
                // Composite primary key: (user_id, id)
                table.primaryKey(userId, id)
            })
            
            #if DEBUG
            print("Recommendations table created successfully with composite primary key")
            #endif
        } catch {
            print("Error creating recommendations table: \(error)")
        }
    }
    
    private func createIndexes() {
        guard let db = db else { return }
        
        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_user_id ON recommendations(user_id)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_timestamp ON recommendations(timestamp)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_user_position ON recommendations(user_id, position)")
            #if DEBUG
            print("Recommendations indexes created successfully")
            #endif
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
                        #if DEBUG
                        print("⚠️ Skipping event without ID at position \(index)")
                        #endif
                        continue
                    }
                    
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
            
            #if DEBUG
            print("✅ \(recommendations.count) recommendations upserted to SQLite for user \(userId)")
            #endif
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
            
            let query = recommendationsTable
                .filter(self.userId == userId)
                .order(position.asc)
            
            for row in try db.prepare(query) {
                guard let data = row[eventData].data(using: .utf8) else {
                    #if DEBUG
                    print("⚠️ Failed to decode event data at position \(row[position])")
                    #endif
                    continue
                }
                
                do {
                    let codableEvent = try decoder.decode(CodableEvent.self, from: data)
                    let event = Event.from(codable: codableEvent)
                    events.append(event)
                } catch {
                    #if DEBUG
                    print("⚠️ Failed to decode event at position \(row[position]): \(error)")
                    #endif
                    continue
                }
            }
            
            #if DEBUG
            print("✅ \(events.count) recommendations loaded from SQLite for user \(userId)")
            #endif
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
            #if DEBUG
            print("✅ \(deleted) recommendations deleted from SQLite for user \(userId)")
            #endif
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
    
    func migrateToCompositeKey() {
        guard let db = db else { return }
        
        do {
            let oldTableExists = try db.scalar(
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='recommendations'"
            ) as! Int64 > 0
            
            if oldTableExists {
                print("!!!! Starting migration to composite key schema...")
                
                try db.run("ALTER TABLE recommendations RENAME TO recommendations_old")
                createTable()
                try db.run("""
                    INSERT INTO recommendations (id, user_id, event_data, score, position, timestamp)
                    SELECT id, user_id, event_data, score, position, timestamp
                    FROM recommendations_old
                """)
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
            
            let allUsersCount = try db.scalar(recommendationsTable.count)
            print("\nTotal recommendations across all users: \(allUsersCount)")
            
        } catch {
            print("❌ Error debugging recommendations database: \(error)")
        }
        
        print("======================================\n")
    }
}

