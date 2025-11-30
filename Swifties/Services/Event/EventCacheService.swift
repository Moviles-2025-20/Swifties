//
//  EventCacheService.swift
//  Swifties
//
//  In-memory cache with thread-safe operations
//

import Foundation

class EventCacheService {
    static let shared = EventCacheService()
    
    private let cache = NSCache<NSString, CachedEventsWrapper>()
    private let cacheKey = "events_cache_key" as NSString
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes = 5.0 // 5 minutes (shorter for frequently changing data)
    
    // Lock for thread-safety in critical operations
    private let lock = NSLock()
    
    private init() {
        // Calculate cache size dynamically based on available memory
        let maxMemory = ProcessInfo.processInfo.physicalMemory
        let cacheSize = Int(maxMemory / 1024 / 8) // Use 1/8th of available memory
        
        cache.countLimit = 15 // Limit to 15 items (more than others because these are general events)
        cache.totalCostLimit = cacheSize
        
        print("Event cache initialized with limit: \(cacheSize) bytes, max items: \(cache.countLimit)")
    }
    
    // MARK: - Thread-Safe Operations
    
    /// Saves events to cache (thread-safe)
    func cacheEvents(_ events: [Event]) {
        lock.lock()
        defer { lock.unlock() }
        
        let wrapper = CachedEventsWrapper(events: events)
        cache.setObject(wrapper, forKey: cacheKey)
        lastCacheTime = Date()
        print("\(events.count) events cached in memory")
    }
    
    /// Obtiene eventos del caché si no han expirado
    func getCachedEvents() -> [Event]? {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if cache has expired
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            cache.removeObject(forKey: cacheKey)
            lastCacheTime = nil
            let elapsed = Date().timeIntervalSince(lastCache)
            print("Cache expired (elapsed: \(Int(elapsed))s)")
            return nil
        }
        
        guard let wrapper = cache.object(forKey: cacheKey) else {
            return nil
        }
        
        let timeElapsed = lastCacheTime.map { Date().timeIntervalSince($0) } ?? 0
        print("Cache hit (\(wrapper.events.count) events, age: \(Int(timeElapsed))s)")
        return wrapper.events
    }
    
    /// Clears the cache
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAllObjects()
        lastCacheTime = nil
        print("Memory cache cleared")
    }
    
    /// Verifica si el caché es válido
    func isCacheValid() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let lastCache = lastCacheTime else { return false }
        
        let timeElapsed = Date().timeIntervalSince(lastCache)
        let hasData = cache.object(forKey: cacheKey) != nil
        return timeElapsed <= cacheExpirationMinutes * 60 && hasData
    }
    
    /// Gets cache age
    func getCacheAge() -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let lastCache = lastCacheTime else { return nil }
        return Date().timeIntervalSince(lastCache)
    }
    
    /// Gets cache information
    func getCacheInfo() -> (count: Int, age: TimeInterval, isValid: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        let wrapper = cache.object(forKey: cacheKey)
        let count = wrapper?.events.count ?? 0
        let age = lastCacheTime.map { Date().timeIntervalSince($0) } ?? 0
        let isValid = age <= cacheExpirationMinutes * 60 && count > 0
        
        return (count, age, isValid)
    }
    
    // MARK: - Debug
    func debugCache() {
        let info = getCacheInfo()
        print("\n=== DEBUG EVENT MEMORY CACHE ===")
        print("Cached events: \(info.count)")
        print("Cache age: \(String(format: "%.1f", info.age/60)) minutes")
        print("Is valid: \(info.isValid)")
        print("Expiration time: \(cacheExpirationMinutes) minutes")
        print("Cache memory limit: \(cache.totalCostLimit) bytes")
        print("Cache item limit: \(cache.countLimit)")
        print("================================\n")
    }
}

// MARK: - Wrapper Class

class CachedEventsWrapper {
    let events: [Event]
    
    init(events: [Event]) {
        self.events = events
    }
}
