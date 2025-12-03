//
//  RecommendationDatabaseManager.swift
//  Swifties
//
//  Refactorizado para usar DatabaseManager singleton
//

import Foundation
import SQLite

class RecommendationDatabaseManager {
    static let shared = RecommendationDatabaseManager()
    
    private let dbManager = DatabaseManager.shared
    
    private init() {
        // Tables are already configured by DatabaseTableManager
    }
    
    // MARK: - CRUD Operations
    
    func saveRecommendations(_ recommendations: [Event], userId: String, completion: ((Bool) -> Void)? = nil) {
        dbManager.executeTransaction { db in
            // Clear existing recommendations for this user
            try db.run(RecommendationsTable.table.filter(RecommendationsTable.userId == userId).delete())
            
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
                guard let eventJSON = String(
                    data: try encoder.encode(codableEvent),
                    encoding: String.Encoding.utf8
                ) else {
                    continue
                }
                
                let insert = RecommendationsTable.table.insert(
                    RecommendationsTable.id <- eventId,
                    RecommendationsTable.userId <- userId,
                    RecommendationsTable.eventData <- eventJSON,
                    RecommendationsTable.position <- index,
                    RecommendationsTable.timestamp <- Date()
                )
                
                try db.run(insert)
            }
            
            // Cleanup: remove any rows for this user that are NOT present
            let newIDs = recommendations.compactMap { $0.id }
            
            if newIDs.isEmpty {
                let delSql = "DELETE FROM recommendations WHERE user_id = ?"
                let delStmt = try db.prepare(delSql)
                try delStmt.run(userId)
            } else {
                let placeholders = newIDs.map { _ in "?" }.joined(separator: ",")
                let delSql = "DELETE FROM recommendations WHERE user_id = ? AND id NOT IN (\(placeholders))"
                let delStmt = try db.prepare(delSql)
                
                var params: [Binding?] = [userId]
                params.append(contentsOf: newIDs)
                try delStmt.run(params)
            }
            
            #if DEBUG
            print("✅ \(recommendations.count) recommendations saved for user \(userId)")
            #endif
        } completion: { result in
            switch result {
            case .success:
                completion?(true)
            case .failure(let error):
                print("❌ Error saving recommendations: \(error)")
                completion?(false)
            }
        }
    }
    
    func loadRecommendations(userId: String, completion: @escaping ([Event]?) -> Void) {
        dbManager.executeRead { db in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var events: [Event] = []
            
            let query = RecommendationsTable.table
                .filter(RecommendationsTable.userId == userId)
                .order(RecommendationsTable.position.asc)
            
            for row in try db.prepare(query) {
                guard let data = row[RecommendationsTable.eventData].data(using: String.Encoding.utf8) else {
                    #if DEBUG
                    print("⚠️ Failed to decode event data at position \(row[RecommendationsTable.position])")
                    #endif
                    continue
                }
                
                do {
                    let codableEvent = try decoder.decode(CodableEvent.self, from: data)
                    let event = Event.from(codable: codableEvent)
                    events.append(event)
                } catch {
                    #if DEBUG
                    print("⚠️ Failed to decode event at position \(row[RecommendationsTable.position]): \(error)")
                    #endif
                    continue
                }
            }
            
            #if DEBUG
            print("✅ \(events.count) recommendations loaded for user \(userId)")
            #endif
            
            return events
        } completion: { result in
            switch result {
            case .success(let events):
                completion(events.isEmpty ? nil : events)
            case .failure(let error):
                print("❌ Error loading recommendations: \(error)")
                completion(nil)
            }
        }
    }
    
    func deleteRecommendations(userId: String, completion: ((Bool) -> Void)? = nil) {
        dbManager.executeWrite { db in
            let deleted = try db.run(
                RecommendationsTable.table
                    .filter(RecommendationsTable.userId == userId)
                    .delete()
            )
            #if DEBUG
            print("✅ \(deleted) recommendations deleted for user \(userId)")
            #endif
        } completion: { result in
            switch result {
            case .success:
                completion?(true)
            case .failure(let error):
                print("❌ Error deleting recommendations: \(error)")
                completion?(false)
            }
        }
    }
    
    func getRecommendationCount(userId: String, completion: @escaping (Int) -> Void) {
        dbManager.executeRead { db in
            try db.scalar(
                RecommendationsTable.table
                    .filter(RecommendationsTable.userId == userId)
                    .count
            )
        } completion: { result in
            completion((try? result.get()) ?? 0)
        }
    }
    
    func getLastUpdateTimestamp(userId: String, completion: @escaping (Date?) -> Void) {
        dbManager.executeRead { db in
            let query = RecommendationsTable.table
                .filter(RecommendationsTable.userId == userId)
                .select(RecommendationsTable.timestamp)
                .order(RecommendationsTable.timestamp.desc)
            
            if let row = try db.pluck(query) {
                return row[RecommendationsTable.timestamp]
            }
            return nil
        } completion: { result in
            completion((try? result.get()) ?? nil)
        }
    }
    
    // MARK: - Debug
    
    func debugDatabase(userId: String) {
        dbManager.executeRead { db in
            let count = try db.scalar(
                RecommendationsTable.table
                    .filter(RecommendationsTable.userId == userId)
                    .count
            )
            
            print("\n=== DEBUG RECOMMENDATIONS TABLE ===")
            print("User ID: \(userId)")
            print("Total recommendations: \(count)")
            
            let query = RecommendationsTable.table
                .filter(RecommendationsTable.userId == userId)
                .order(RecommendationsTable.position.asc)
                .limit(5)
            
            print("\nFirst 5 recommendations:")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for row in try db.prepare(query) {
                guard let data = row[RecommendationsTable.eventData].data(using: String.Encoding.utf8) else { continue }
                
                if let codableEvent = try? decoder.decode(CodableEvent.self, from: data) {
                    print("  Position \(row[RecommendationsTable.position]): \(codableEvent.name)")
                }
            }
            
            print("===================================\n")
        } completion: { _ in }
    }
}
