//
//  RecommendationStorageService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation

class RecommendationStorageService {
    static let shared = RecommendationStorageService()
    
    private let databaseManager = RecommendationDatabaseManager.shared
    private let userDefaults = UserDefaults.standard
    private let timestampKey = "recommendations_timestamp"
    private let storageExpirationHours = 24.0
    
    private init() {}
    
    func saveRecommendationsToStorage(_ recommendations: [Event], userId: String) {
        databaseManager.saveRecommendations(recommendations, userId: userId)
        
        let key = "\(timestampKey)_\(userId)"
        let now = Date()
        userDefaults.set(now, forKey: key)
        
        #if DEBUG
        print("\(recommendations.count) recommendations saved to storage at \(now)")
        #endif
    }
    
    func loadRecommendationsFromStorage(userId: String) -> [Event]? {
        let key = "\(timestampKey)_\(userId)"
        guard let timestamp = userDefaults.object(forKey: key) as? Date else {
            #if DEBUG
            print("No timestamp found for recommendations")
            #endif
            return nil
        }
        
        let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
        #if DEBUG
        print("Recommendations storage age: \(String(format: "%.1f", hoursElapsed)) hours")
        #endif
        
        if hoursElapsed > storageExpirationHours {
            clearStorage(userId: userId)
            return nil
        }
        
        guard let recommendations = databaseManager.loadRecommendations(userId: userId) else {
            #if DEBUG
            print("No recommendations found in storage")
            #endif
            return nil
        }
        
        #if DEBUG
        print("\(recommendations.count) recommendations loaded from storage")
        #endif
        return recommendations
    }
    
    func clearStorage(userId: String) {
        databaseManager.deleteRecommendations(userId: userId)
        let key = "\(timestampKey)_\(userId)"
        userDefaults.removeObject(forKey: key)
        #if DEBUG
        print("Recommendations storage cleared for user: \(userId)")
        #endif
    }
    
    func debugStorage(userId: String) {
        #if DEBUG
        print("\n=== DEBUG RECOMMENDATIONS STORAGE ===")
        
        let key = "\(timestampKey)_\(userId)"
        if let timestamp = userDefaults.object(forKey: key) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("Timestamp: \(timestamp)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
        } else {
            print("No timestamp")
        }
        
        let count = databaseManager.getRecommendationCount(userId: userId)
        print("Recommendations in database: \(count)")
        
        if let lastUpdate = databaseManager.getLastUpdateTimestamp(userId: userId) {
            print("Last database update: \(lastUpdate)")
        }
        
        print("====================================\n")
        
        databaseManager.debugDatabase(userId: userId)
        #endif
    }
    
    func getStorageInfo(userId: String) -> RecommendationStorageInfo {
        let count = databaseManager.getRecommendationCount(userId: userId)
        let key = "\(timestampKey)_\(userId)"
        let timestamp = userDefaults.object(forKey: key) as? Date
        let isExpired: Bool
        
        if let timestamp = timestamp {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            isExpired = hoursElapsed > storageExpirationHours
        } else {
            isExpired = true
        }
        
        return RecommendationStorageInfo(
            recommendationCount: count,
            lastUpdate: timestamp,
            isExpired: isExpired
        )
    }
}

// MARK: - Storage Info Model

struct RecommendationStorageInfo {
    let recommendationCount: Int
    let lastUpdate: Date?
    let isExpired: Bool
    
    var ageInHours: Double? {
        guard let lastUpdate = lastUpdate else { return nil }
        return Date().timeIntervalSince(lastUpdate) / 3600
    }
}

