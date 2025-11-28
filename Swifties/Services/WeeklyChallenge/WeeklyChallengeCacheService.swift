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
    private let cacheExpirationSeconds: TimeInterval = 3600
    
    // Cachear el weekId actual (se actualiza solo cuando cambia la semana)
    private var cachedWeekId: String?
    private var weekIdTimestamp: Date?
    
    private init() {}
    
    // MARK: - Helper Methods (Evitar recreación)
    
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
    
    // MARK: - Cache Operations (Refactorizadas)
    
    func getCachedChallenge(userId: String) -> WeeklyChallengeCache? {
        let key = cacheKey(for: userId)  // Reutiliza método
        
        guard let cached = cache[key] else {
            print("❌ No cache found for key: \(key)")
            return nil
        }
        
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
        let key = cacheKey(for: userId)  //  Reutiliza método
        
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
        let key = cacheKey(for: userId)  //  Reutiliza método
        cache.removeValue(forKey: key)
        print("🗑️ Cache cleared for key: \(key)")
    }
    
    func debugCache(userId: String) {
        let key = cacheKey(for: userId)  //  Reutiliza método
        
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

