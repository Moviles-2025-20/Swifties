//
//  UserEventCacheService.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
//

import Foundation

class UserEventCacheService {
    static let shared = UserEventCacheService()
    
    private let cache = NSCache<NSString, CachedUserEventWrapper>()
    private let cacheKey = "user_events_cache_key" as NSString
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes = 15.0 // Shorter because it depends on user preferences
    
    private init() {
        // Calculate cache size dynamically based on available memory
        let maxMemory = ProcessInfo.processInfo.physicalMemory
        let cacheSize = Int(maxMemory / 1024 / 16) // Use 1/16th of available memory (more conservative than recommendations)
        
        cache.countLimit = 10 // Limit to 10 items
        cache.totalCostLimit = cacheSize
        
        print("User Event cache initialized with limit: \(cacheSize) bytes, max items: \(cache.countLimit)")
    }
    
    func getCachedUserEvents() -> UserEventCache? {
        // Check if cache has expired
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        
        guard let wrapper = cache.object(forKey: cacheKey) else {
            return nil
        }
        
        print("User events retrieved from memory cache")
        return wrapper.userEventCache
    }
    
    func cacheUserEvents(_ availableEvents: [Event], freeTimeSlots: [FreeTimeSlot]) {
        let eventCache = UserEventCache(
            availableEvents: availableEvents,
            freeTimeSlots: freeTimeSlots
        )
        let wrapper = CachedUserEventWrapper(userEventCache: eventCache)
        cache.setObject(wrapper, forKey: cacheKey)
        lastCacheTime = Date()
        print("User events saved to memory cache: \(availableEvents.count) events, \(freeTimeSlots.count) slots")
    }
    
    func clearCache() {
        cache.removeAllObjects()
        lastCacheTime = nil
        print("User events memory cache cleared")
    }
    
    func getCacheAge() -> TimeInterval? {
        guard let lastCache = lastCacheTime else { return nil }
        return Date().timeIntervalSince(lastCache)
    }
    
    func debugCache() {
        print("\n=== DEBUG USER EVENT CACHE ===")
        
        if let wrapper = cache.object(forKey: cacheKey),
           let age = getCacheAge() {
            print("Found: YES")
            print("Age: \(String(format: "%.1f", age/60)) minutes")
            print("Available Events: \(wrapper.userEventCache.availableEvents.count)")
            print("Free Time Slots: \(wrapper.userEventCache.freeTimeSlots.count)")
            print("Expired: \(age > cacheExpirationMinutes * 60)")
        } else {
            print("Found: NO")
        }
        
        print("Cache expiration: \(cacheExpirationMinutes) minutes")
        print("Cache memory limit: \(cache.totalCostLimit) bytes")
        print("Cache item limit: \(cache.countLimit)")
        print("==============================\n")
    }
}

// MARK: - Cache Models

struct UserEventCache {
    let availableEvents: [Event]
    let freeTimeSlots: [FreeTimeSlot]
}

class CachedUserEventWrapper {
    let userEventCache: UserEventCache
    
    init(userEventCache: UserEventCache) {
        self.userEventCache = userEventCache
    }
}
