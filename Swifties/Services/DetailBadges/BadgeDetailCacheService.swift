//
//  BadgeDetailCacheService.swift
//  Swifties
//
//  Layer 1: Memory Cache for Badge Detail
//

import Foundation

class BadgeDetailCacheService {
    static let shared = BadgeDetailCacheService()
    
    private var cache: [String: CachedBadgeDetail] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    private struct CachedBadgeDetail {
        let detail: BadgeDetail
        let timestamp: Date
    }
    
    // MARK: - Cache Operations
    
    func cacheDetail(badgeId: String, userId: String, detail: BadgeDetail) {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        cache[key] = CachedBadgeDetail(detail: detail, timestamp: Date())
        print("💾 Cached badge detail in memory: \(key)")
    }
    
    func getCachedDetail(badgeId: String, userId: String) -> BadgeDetail? {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        
        guard let cached = cache[key] else {
            print("❌ No memory cache for: \(key)")
            return nil
        }
        
        let age = Date().timeIntervalSince(cached.timestamp)
        if age > cacheExpirationTime {
            print("⏰ Memory cache expired for: \(key)")
            cache.removeValue(forKey: key)
            return nil
        }
        
        print("✅ Found valid memory cache for: \(key)")
        return cached.detail
    }
    
    func clearCache(badgeId: String, userId: String) {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        cache.removeValue(forKey: key)
        print("🗑️ Cleared memory cache for: \(key)")
    }
    
    func clearAllCache() {
        cache.removeAll()
        print("🗑️ Cleared all badge detail memory cache")
    }
    
    // MARK: - Helper
    
    private func cacheKey(badgeId: String, userId: String) -> String {
        return "\(userId)_\(badgeId)"
    }
    
    // MARK: - Debug
    
    func debugCache(badgeId: String, userId: String) {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        if let cached = cache[key] {
            let age = Date().timeIntervalSince(cached.timestamp)
            print("🔍 Cache status for \(key): exists, age: \(age)s")
        } else {
            print("🔍 Cache status for \(key): not found")
        }
    }
}
