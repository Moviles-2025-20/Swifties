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
    
    func saveRecommendationsToStorage(_ recommendations: [Event], userId: String, completion: (() -> Void)? = nil) {
        databaseManager.saveRecommendations(recommendations, userId: userId) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                let key = "\(self.timestampKey)_\(userId)"
                self.userDefaults.set(Date(), forKey: key)
                
                #if DEBUG
                print("\(recommendations.count) recommendations saved to storage")
                #endif
            } else {
                #if DEBUG
                print("❌ Error saving recommendations")
                #endif
            }
            
            completion?()
        }
    }
    
    func loadRecommendationsFromStorage(userId: String, completion: @escaping ([Event]?) -> Void) {
        let key = "\(timestampKey)_\(userId)"
        guard let timestamp = userDefaults.object(forKey: key) as? Date else {
            #if DEBUG
            print("No timestamp found for recommendations")
            #endif
            completion(nil)
            return
        }
        
        let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
        #if DEBUG
        print("Recommendations storage age: \(String(format: "%.1f", hoursElapsed)) hours")
        #endif
        
        if hoursElapsed > storageExpirationHours {
            clearStorage(userId: userId) {
                completion(nil)
            }
            return
        }
        
        databaseManager.loadRecommendations(userId: userId) { recommendations in
            guard let recommendations = recommendations else {
                #if DEBUG
                print("No recommendations found in storage")
                #endif
                completion(nil)
                return
            }
            
            #if DEBUG
            print("\(recommendations.count) recommendations loaded from storage")
            #endif
            completion(recommendations)
        }
    }
    
    func clearStorage(userId: String, completion: (() -> Void)? = nil) {
        databaseManager.deleteRecommendations(userId: userId) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                let key = "\(self.timestampKey)_\(userId)"
                self.userDefaults.removeObject(forKey: key)
                
                #if DEBUG
                print("Recommendations storage cleared for user: \(userId)")
                #endif
            } else {
                #if DEBUG
                print("❌ Error clearing recommendations")
                #endif
            }
            
            completion?()
        }
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
        
        databaseManager.getRecommendationCount(userId: userId) { count in
            print("Recommendations in database: \(count)")
            
            self.databaseManager.getLastUpdateTimestamp(userId: userId) { lastUpdate in
                if let lastUpdate = lastUpdate {
                    print("Last database update: \(lastUpdate)")
                }
                
                print("====================================\n")
                
                self.databaseManager.debugDatabase(userId: userId)
            }
        }
        #endif
    }
    
    func getStorageInfo(userId: String, completion: @escaping (RecommendationStorageInfo) -> Void) {
        databaseManager.getRecommendationCount(userId: userId) { [weak self] count in
            guard let self = self else { return }
            
            let key = "\(self.timestampKey)_\(userId)"
            let timestamp = self.userDefaults.object(forKey: key) as? Date
            let isExpired: Bool
            
            if let timestamp = timestamp {
                let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
                isExpired = hoursElapsed > self.storageExpirationHours
            } else {
                isExpired = true
            }
            
            let info = RecommendationStorageInfo(
                recommendationCount: count,
                lastUpdate: timestamp,
                isExpired: isExpired
            )
            
            completion(info)
        }
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
