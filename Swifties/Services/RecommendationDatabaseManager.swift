//
//  RecommendationDatabaseManager.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 29/10/25.
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
                table.column(id, primaryKey: true)
                table.column(userId)
                table.column(eventData)
                table.column(score)
                table.column(position)
                table.column(timestamp)
            })
            
            print("Recommendations table created successfully")
        } catch {
            print("Error creating recommendations table: \(error)")
        }
    }
    
    private func createIndexes() {
        guard let db = db else { return }
        
        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_user_id ON recommendations(user_id)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_timestamp ON recommendations(timestamp)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_recommendations_position ON recommendations(position)")
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
                for (index, event) in recommendations.enumerated() {
                    guard let eventId = event.id else { continue }
                    
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
            
            print("\(recommendations.count) recommendations saved to SQLite database")
        } catch {
            print("Error saving recommendations: \(error)")
        }
    }
    
    func loadRecommendations(userId: String) -> [Event]? {
        guard let db = db else {
            print("Database connection not available")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            var events: [Event] = []
            
            // Load recommendations ordered by position
            let query = recommendationsTable
                .filter(self.userId == userId)
                .order(position.asc)
            
            for row in try db.prepare(query) {
                guard let data = row[eventData].data(using: .utf8) else { continue }
                // Decode as CodableEvent and convert to Event
                let codableEvent = try decoder.decode(CodableEvent.self, from: data)
                let event = Event.from(codable: codableEvent)
                events.append(event)
            }
            
            print("\(events.count) recommendations loaded from SQLite database")
            return events.isEmpty ? nil : events
        } catch {
            print("Error loading recommendations: \(error)")
            return nil
        }
    }
    
    func deleteRecommendations(userId: String) {
        guard let db = db else { return }
        
        do {
            try db.run(recommendationsTable.filter(self.userId == userId).delete())
            print("Recommendations deleted from SQLite for user: \(userId)")
        } catch {
            print("Error deleting recommendations: \(error)")
        }
    }
    
    func getRecommendationCount(userId: String) -> Int {
        guard let db = db else { return 0 }
        
        do {
            return try db.scalar(recommendationsTable.filter(self.userId == userId).count)
        } catch {
            print("Error getting recommendation count: \(error)")
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
            print("Error getting recommendations timestamp: \(error)")
            return nil
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
                print("Last update: \(lastUpdate)")
            }
            
            // Show first 3 recommendations
            let query = recommendationsTable
                .filter(self.userId == userId)
                .order(position.asc)
                .limit(3)
            
            for row in try db.prepare(query) {
                guard let data = row[eventData].data(using: .utf8) else { continue }
                let decoder = JSONDecoder()
                let codableEvent = try decoder.decode(CodableEvent.self, from: data)
                print("Position \(row[position]): \(codableEvent.name)")
            }
        } catch {
            print("Error debugging recommendations database: \(error)")
        }
        
        print("======================================\n")
    }
}
