//
//  EventCacheService.swift
//  Swifties
//
//  In-memory cache with thread-safe operations
//

import Foundation

class EventCacheService {
    static let shared = EventCacheService()
    
    private var cachedEvents: [Event]?
    private var cacheTimestamp: Date?
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutos
    
    // Lock para thread-safety (alternativa a ThreadManager para operaciones síncronas)
    private let lock = NSLock()
    
    private let threadManager = ThreadManager.shared
    
    private init() {}
    
    // MARK: - Operaciones Thread-Safe
    
    /// Guarda eventos en caché (thread-safe con barrier)
    func cacheEvents(_ events: [Event]) {
        lock.lock()
        defer { lock.unlock() }
        
        self.cachedEvents = events
        self.cacheTimestamp = Date()
        print("\(events.count) events cached in memory")
    }
    
    /// Obtiene eventos del caché si no han expirado
    func getCachedEvents() -> [Event]? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let cached = cachedEvents,
              let timestamp = cacheTimestamp else {
            return nil
        }
        
        // Verificar si el caché no ha expirado
        let timeElapsed = Date().timeIntervalSince(timestamp)
        if timeElapsed > cacheExpirationTime {
            print("Cache expired (elapsed: \(Int(timeElapsed))s)")
            cachedEvents = nil
            cacheTimestamp = nil
            return nil
        }
        
        print("Cache hit (\(cached.count) events, age: \(Int(timeElapsed))s)")
        return cached
    }
    
    /// Limpia el caché
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        
        cachedEvents = nil
        cacheTimestamp = nil
        print("Memory cache cleared")
    }
    
    /// Verifica si el caché es válido
    func isCacheValid() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        guard let timestamp = cacheTimestamp else { return false }
        
        let timeElapsed = Date().timeIntervalSince(timestamp)
        return timeElapsed <= cacheExpirationTime
    }
    
    /// Obtiene información del caché
    func getCacheInfo() -> (count: Int, age: TimeInterval, isValid: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        let count = cachedEvents?.count ?? 0
        let age = cacheTimestamp.map { Date().timeIntervalSince($0) } ?? 0
        let isValid = age <= cacheExpirationTime && count > 0
        
        return (count, age, isValid)
    }
    
    // MARK: - Debug
    
    func debugCache() {
        let info = getCacheInfo()
        print("\n=== DEBUG MEMORY CACHE ===")
        print("Cached events: \(info.count)")
        print("Cache age: \(Int(info.age))s")
        print("Is valid: \(info.isValid)")
        print("Expiration time: \(Int(cacheExpirationTime))s")
        print("=========================\n")
    }
}
