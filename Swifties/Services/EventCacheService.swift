//
//  EventCacheService.swift
//  Swifties
//
//  Created by Imac  on 25/10/25.
//

import Foundation

class EventCacheService {
    static let shared = EventCacheService()
    
    private var memoryCache: [Event] = []
    private let cacheLimit = 10
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes = 30.0
    
    private init() {}
    
    func getCachedEvents() -> [Event]? {
        guard !memoryCache.isEmpty else { return nil }
        
        // Verificar si el caché ha expirado
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        
        print("✅ Eventos obtenidos de caché en memoria")
        return memoryCache
    }
    
    func cacheEvents(_ events: [Event]) {
        memoryCache = Array(events.prefix(cacheLimit))
        lastCacheTime = Date()
        print("💾 \(memoryCache.count) eventos guardados en caché de memoria")
    }
    
    func clearCache() {
        memoryCache.removeAll()
        lastCacheTime = nil
        print("🗑️ Caché de memoria limpiado")
    }
}
