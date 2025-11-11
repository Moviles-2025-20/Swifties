//
//  WeeklyChallengeCacheService.swift
//  Swifties
//
//  Layer 1: In-Memory Cache for Weekly Challenge
//

import Foundation

class WeeklyChallengeCacheService {
    static let shared = WeeklyChallengeCacheService()
    
    private var cache: [String: WeeklyChallengeCache] = [:]
    private let cacheExpirationSeconds: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // MARK: - Cache Operations
    
    func getCachedChallenge(userId: String) -> WeeklyChallengeCache? {
        let weekId = Date().weekIdentifier()
        let key = "\(userId)_\(weekId)"
        
        guard let cached = cache[key] else {
            print("❌ No cache found for key: \(key)")
            return nil
        }
        
        // Check if cache is still valid
        let age = Date().timeIntervalSince(cached.timestamp)
        if age > cacheExpirationSeconds {
            print("⏰ Cache expired (age: \(String(format: "%.1f", age/60)) minutes)")
            cache.removeValue(forKey: key)
            return nil
        }
        
        print("✅ Cache hit for key: \(key) (age: \(String(format: "%.1f", age/60)) minutes)")
        return cached
    }
    
    func cacheChallenge(userId: String, event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData]) {
        let weekId = Date().weekIdentifier()
        let key = "\(userId)_\(weekId)"
        
        let cache = WeeklyChallengeCache(
            event: event,
            hasAttended: hasAttended,
            totalChallenges: totalChallenges,
            chartData: chartData,
            timestamp: Date()
        )
        
        self.cache[key] = cache
        print("💾 Cached challenge for key: \(key)")
    }
    
    func clearCache(userId: String) {
        let weekId = Date().weekIdentifier()
        let key = "\(userId)_\(weekId)"
        cache.removeValue(forKey: key)
        print("🗑️ Cache cleared for key: \(key)")
    }
    
    func clearAllCache() {
        cache.removeAll()
        print("🗑️ All cache cleared")
    }
    
    // MARK: - Debug
    
    func debugCache(userId: String) {
        let weekId = Date().weekIdentifier()
        let key = "\(userId)_\(weekId)"
        
        print("\n=== DEBUG WEEKLY CHALLENGE CACHE ===")
        print("Key: \(key)")
        
        if let cached = cache[key] {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("Found: YES")
            print("Age: \(String(format: "%.1f", age/60)) minutes")
            print("Event: \(cached.event?.name ?? "nil")")
            print("Has Attended: \(cached.hasAttended)")
            print("Total Challenges: \(cached.totalChallenges)")
            print("Valid: \(cached.isValid)")
        } else {
            print("Found: NO")
        }
        
        print("Total cached items: \(cache.count)")
        print("=====================================\n")
    }
}
