//
//  DatabaseTables.swift
//  Swifties
//
//  Centralized definitions for all SQLite tables
//

import Foundation
import SQLite

// MARK: - Events Table

struct EventsTable {
    static let table = Table("events")
    
    // Columns
    static let id = Expression<String>("id")
    static let activetrue = Expression<Bool>("activetrue")
    static let category = Expression<String>("category")
    static let created = Expression<String>("created")
    static let description = Expression<String>("description")
    static let eventType = Expression<String>("event_type")
    static let locationData = Expression<String?>("location_data")
    static let metadataData = Expression<String>("metadata_data")
    static let name = Expression<String>("name")
    static let scheduleData = Expression<String>("schedule_data")
    static let statsData = Expression<String>("stats_data")
    static let title = Expression<String>("title")
    static let type = Expression<String>("type")
    static let weatherDependent = Expression<Bool>("weather_dependent")
    static let timestamp = Expression<Date>("timestamp")
    
    // Schema creation
    static func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(activetrue)
            t.column(category)
            t.column(created)
            t.column(description)
            t.column(eventType)
            t.column(locationData)
            t.column(metadataData)
            t.column(name)
            t.column(scheduleData)
            t.column(statsData)
            t.column(title)
            t.column(type)
            t.column(weatherDependent)
            t.column(timestamp)
        })
        
        #if DEBUG
        print("✅ Events table created")
        #endif
    }
    
    static func createIndexes(in db: Connection) throws {
        try db.run("CREATE INDEX IF NOT EXISTS idx_events_category ON events(category)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_events_event_type ON events(event_type)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp)")
        
        #if DEBUG
        print("✅ Events indexes created")
        #endif
    }
}

// MARK: - Recommendations Table

struct RecommendationsTable {
    static let table = Table("recommendations")
    
    // Columns
    static let id = Expression<String>("id")
    static let userId = Expression<String>("user_id")
    static let eventData = Expression<String>("event_data")
    static let position = Expression<Int>("position")
    static let timestamp = Expression<Date>("timestamp")
    
    // Schema creation
    static func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id)
            t.column(userId)
            t.column(eventData)
            t.column(position)
            t.column(timestamp)
            
            // Composite primary key
            t.primaryKey(userId, id)
        })
        
        #if DEBUG
        print("✅ Recommendations table created")
        #endif
    }
    
    static func createIndexes(in db: Connection) throws {
        try db.run("CREATE INDEX IF NOT EXISTS idx_rec_user_id ON recommendations(user_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_rec_timestamp ON recommendations(timestamp)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_rec_user_position ON recommendations(user_id, position)")
        
        #if DEBUG
        print("✅ Recommendations indexes created")
        #endif
    }
}


// MARK: - Quiz Questions Table

struct QuizQuestionsTable {
    static let table = Table("quiz_questions")
    
    // Columns
    static let id = Expression<String>("id")
    static let text = Expression<String>("text")
    static let imageUrl = Expression<String?>("image_url")
    static let optionsJson = Expression<String>("options_json")
    static let timestamp = Expression<Date>("timestamp")
    
    // Schema creation
    static func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(text)
            t.column(imageUrl)
            t.column(optionsJson)
            t.column(timestamp)
        })
        
        #if DEBUG
        print("✅ Quiz questions table created")
        #endif
    }
    
    static func createIndexes(in db: Connection) throws {
        try db.run("CREATE INDEX IF NOT EXISTS idx_quiz_timestamp ON quiz_questions(timestamp)")
        
        #if DEBUG
        print("✅ Quiz questions indexes created")
        #endif
    }
}

// MARK: - Update DatabaseTableManager

// Update the setupAllTables() function to include quiz tables:
class DatabaseTableManager {
    static func setupAllTables() {
        guard let db = DatabaseManager.shared.connection else {
            print("❌ Cannot setup tables: database not available")
            return
        }
        
        do {
            try EventsTable.createTable(in: db)
            try EventsTable.createIndexes(in: db)
            
            try RecommendationsTable.createTable(in: db)
            try RecommendationsTable.createIndexes(in: db)
            
            // Quiz tables
            try QuizQuestionsTable.createTable(in: db)
            try QuizQuestionsTable.createIndexes(in: db)
            
            #if DEBUG
            print("✅ All database tables initialized")
            #endif
        } catch {
            print("❌ Error setting up tables: \(error)")
        }
    }
}
