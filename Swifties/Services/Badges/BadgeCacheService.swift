//
//  BadgeCacheService.swift
//  Swifties
//
//  Layer 1: In-Memory Cache for Badges
//

import Foundation

struct BadgeCache {
    let badges: [Badge]
    let userBadges: [UserBadge]
    let timestamp: Date
    
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < 3600 // 1 hour
    }
}

class BadgeCacheService {
    static let shared = BadgeCacheService()
    
    private var cache: [String: BadgeCache] = [:]
    private let cacheExpirationSeconds: TimeInterval = 3600 // 1 hour
    
    private init() {}
    

    func getCachedBadges(userId: String) -> BadgeCache? {
        guard let cached = cache[userId] else {
            print("❌ No badge cache found for user: \(userId)")
            return nil
        }
        
        let age = Date().timeIntervalSince(cached.timestamp)
        if age > cacheExpirationSeconds {
            print("⏰ Badge cache expired (age: \(String(format: "%.1f", age/60)) minutes)")
            cache.removeValue(forKey: userId)
            return nil
        }
        
        print("✅ Badge cache hit for user: \(userId) (age: \(String(format: "%.1f", age/60)) minutes)")
        return cached
    }
    
    func cacheBadges(userId: String, badges: [Badge], userBadges: [UserBadge]) {
        let cache = BadgeCache(
            badges: badges,
            userBadges: userBadges,
            timestamp: Date()
        )
        
        self.cache[userId] = cache
        print("💾 Cached \(badges.count) badges for user: \(userId)")
    }
    
    func clearCache(userId: String) {
        cache.removeValue(forKey: userId)
        print("🗑️ Badge cache cleared for user: \(userId)")
    }
    
    func clearAllCache() {
        cache.removeAll()
        print("🗑️ All badge cache cleared")
    }
    
    // MARK: - Debug
    
    func debugCache(userId: String) {
        print("\n=== DEBUG BADGE CACHE ===")
        print("User ID: \(userId)")
        
        if let cached = cache[userId] {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("Found: YES")
            print("Age: \(String(format: "%.1f", age/60)) minutes")
            print("Badges: \(cached.badges.count)")
            print("User Badges: \(cached.userBadges.count)")
            print("Valid: \(cached.isValid)")
        } else {
            print("Found: NO")
        }
        
        print("Total cached users: \(cache.count)")
        print("=========================\n")
    }
}
