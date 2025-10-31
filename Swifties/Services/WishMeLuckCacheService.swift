//
//  WishMeLuckCacheService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation

actor WishMeLuckCacheService {
    static let shared = WishMeLuckCacheService()
    
    private var cache: [String: WishMeLuckCache] = [:]
    private let cacheExpirationSeconds: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // MARK: - Cache Operations
    
    func getCachedDaysSinceLastWished(userId: String) -> WishMeLuckCache? {
        guard let cached = cache[userId] else {
            print("❌ No cache found for user: \(userId)")
            return nil
        }
        
        // Check if cache is still valid
        let age = Date().timeIntervalSince(cached.timestamp)
        if age > cacheExpirationSeconds {
            print("⏰ Cache expired (age: \(String(format: "%.1f", age/60)) minutes)")
            cache.removeValue(forKey: userId)
            return nil
        }
        
        print("✅ Cache hit for user: \(userId) (age: \(String(format: "%.1f", age/60)) minutes)")
        return cached
    }
    
    func cacheDaysSinceLastWished(userId: String, days: Int, lastWishedDate: Date?) {
        let cacheData = WishMeLuckCache(
            daysSinceLastWished: days,
            lastWishedDate: lastWishedDate,
            timestamp: Date()
        )
        
        self.cache[userId] = cacheData
        print("💾 Cached days since last wished for user: \(userId) - \(days) days")
    }
    
    func clearCache(userId: String) {
        cache.removeValue(forKey: userId)
        print("🗑️ Cache cleared for user: \(userId)")
    }
    
    func clearAllCache() {
        cache.removeAll()
        print("🗑️ All Wish Me Luck cache cleared")
    }
    
    // MARK: - Debug
    
    func debugCache(userId: String) {
        print("\n=== DEBUG WISH ME LUCK CACHE ===")
        print("User ID: \(userId)")
        
        if let cached = cache[userId] {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("Found: YES")
            print("Age: \(String(format: "%.1f", age/60)) minutes")
            print("Days Since Last Wished: \(cached.daysSinceLastWished)")
            print("Last Wished Date: \(cached.lastWishedDate?.description ?? "nil")")
            print("Valid: \(cached.isValid)")
        } else {
            print("Found: NO")
        }
        
        print("Total cached items: \(cache.count)")
        print("====================================\n")
    }
}
