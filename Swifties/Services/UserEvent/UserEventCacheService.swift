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
    private let cacheLimit = 10
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes = 15.0 // Shorter because it depends on user preferences
    
    private init() {
        cache.countLimit = cacheLimit
        cache.totalCostLimit = 1024 * 1024 * 5 // 5 MB (menor que eventos generales)
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
