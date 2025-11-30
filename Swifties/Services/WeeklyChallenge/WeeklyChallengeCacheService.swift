//
//  WeeklyChallengeCacheService.swift
//  Swifties
//
//  Layer 1: In-Memory Cache for Weekly Challenge
//

import Foundation

class WeeklyChallengeCacheService {
    static let shared = WeeklyChallengeCacheService()
    
    private let cache = NSCache<NSString, CachedWeeklyChallengeWrapper>()
    private let cacheExpirationMinutes = 60.0 // 1 hour
    
    // Cache the current weekId (updates only when the week changes)
    private var cachedWeekId: String?
    private var weekIdTimestamp: Date?
    
    private init() {
        // Calculate cache size dynamically based on available memory
        let maxMemory = ProcessInfo.processInfo.physicalMemory
        let cacheSize = Int(maxMemory / 1024 / 8) // Use 1/8th of available memory for cache
        
        cache.countLimit = 10 // Limit to 10 items (can be adjusted as needed)
        cache.totalCostLimit = cacheSize
        
        print("Weekly Challenge cache initialized with limit: \(cacheSize) bytes, max items: \(cache.countLimit)")
    }
    
    // MARK: - Helper Methods
    
    private var currentWeekId: String {
        let now = Date()
        
        if let cached = cachedWeekId,
           let timestamp = weekIdTimestamp,
           now.timeIntervalSince(timestamp) < 3600 {
            return cached
        }
        
        let newWeekId = now.weekIdentifier()
        cachedWeekId = newWeekId
        weekIdTimestamp = now
        return newWeekId
    }
    
    private func cacheKey(for userId: String) -> String {
        "\(userId)_\(currentWeekId)"
    }
    
    // MARK: - Cache Operations
    
    func getCachedChallenge(userId: String) -> WeeklyChallengeCache? {
        let key = cacheKey(for: userId)
        
        guard let wrapper = cache.object(forKey: key as NSString) else {
            print("❌ No cache found for key: \(key)")
            return nil
        }
        
        // Check if cache has expired
        let age = Date().timeIntervalSince(wrapper.timestamp)
        if age > cacheExpirationMinutes * 60 {
            print("⏰ Cache expired (age: \(String(format: "%.1f", age/60)) minutes)")
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        
        print("✅ Cache hit for key: \(key) (age: \(String(format: "%.1f", age/60)) minutes)")
        return wrapper.challenge
    }
    
    func cacheChallenge(userId: String, event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData]) {
        let key = cacheKey(for: userId)
        
        let challenge = WeeklyChallengeCache(
            event: event,
            hasAttended: hasAttended,
            totalChallenges: totalChallenges,
            chartData: chartData,
            timestamp: Date()
        )
        
        let wrapper = CachedWeeklyChallengeWrapper(challenge: challenge, timestamp: Date())
        cache.setObject(wrapper, forKey: key as NSString)
        
        print("💾 Cached challenge for key: \(key)")
    }
    
    func clearCache(userId: String? = nil) {
        if let userId = userId {
            let key = cacheKey(for: userId)
            cache.removeObject(forKey: key as NSString)
            print("🗑️ Cache cleared for key: \(key)")
        } else {
            cache.removeAllObjects()
            cachedWeekId = nil
            weekIdTimestamp = nil
            print("🗑️ All cache cleared")
        }
    }
    
    func getCacheAge(userId: String) -> TimeInterval? {
        let key = cacheKey(for: userId)
        guard let wrapper = cache.object(forKey: key as NSString) else {
            return nil
        }
        return Date().timeIntervalSince(wrapper.timestamp)
    }
    
    func debugCache(userId: String) {
        let key = cacheKey(for: userId)
        
        print("\n=== DEBUG WEEKLY CHALLENGE CACHE ===")
        print("Key: \(key)")
        
        if let wrapper = cache.object(forKey: key as NSString) {
            let age = Date().timeIntervalSince(wrapper.timestamp)
            let cached = wrapper.challenge
            print("Found: YES")
            print("Age: \(String(format: "%.1f", age/60)) minutes")
            print("Event: \(cached.event?.name ?? "nil")")
            print("Has Attended: \(cached.hasAttended)")
            print("Total Challenges: \(cached.totalChallenges)")
            print("Valid: \(cached.isValid)")
            print("Expired: \(age > cacheExpirationMinutes * 60)")
        } else {
            print("Found: NO")
        }
        
        print("Cache memory limit: \(cache.totalCostLimit) bytes")
        print("Cache item limit: \(cache.countLimit)")
        print("=====================================\n")
    }
}

// MARK: - Wrapper Class

class CachedWeeklyChallengeWrapper {
    let challenge: WeeklyChallengeCache
    let timestamp: Date
    
    init(challenge: WeeklyChallengeCache, timestamp: Date) {
        self.challenge = challenge
        self.timestamp = timestamp
    }
}
