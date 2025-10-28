//
//  EventCacheService.swift
//  Swifties
//
//  Created by Imac  on 25/10/25.
//

import Foundation

class EventCacheService {
    static let shared = EventCacheService()
    
    private let cache = NSCache<NSString, CachedEventWrapper>()
    private let cacheKey = "events_cache_key" as NSString
    private let cacheLimit = 10
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes = 30.0
    
    private init() {
        cache.countLimit = cacheLimit
        cache.totalCostLimit = 1024 * 1024 * 10 // 10 MB
    }
    
    func getCachedEvents() -> [Event]? {
        // Check if cache has expired
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        
        guard let wrapper = cache.object(forKey: cacheKey) else {
            return nil
        }
        
        print("Events retrieved from memory cache")
        return wrapper.events
    }
    
    func cacheEvents(_ events: [Event]) {
        let eventsToCache = Array(events.prefix(cacheLimit))
        let wrapper = CachedEventWrapper(events: eventsToCache)
        cache.setObject(wrapper, forKey: cacheKey)
        lastCacheTime = Date()
        print("\(eventsToCache.count) events saved to memory cache")
    }
    
    func clearCache() {
        cache.removeAllObjects()
        lastCacheTime = nil
        print("Memory cache cleared")
    }
}

// Wrapper class to store events in NSCache (NSCache requires reference types)
class CachedEventWrapper {
    let events: [Event]
    
    init(events: [Event]) {
        self.events = events
    }
}
