//
//  BadgeDetailCacheService.swift
//  Swifties
//
//  Layer 1: Memory Cache for Badge Detail with ESTRATEGIA 1: Dispatcher
//

import Foundation

class BadgeDetailCacheService {
    static let shared = BadgeDetailCacheService()
    
    private var cache: [String: CachedBadgeDetail] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // ESTRATEGIA 1: Queue serial para sincronización thread-safe
    private let cacheQueue = DispatchQueue(label: "com.swifties.badgeDetailCache", qos: .userInitiated)
    
    private init() {}
    
    private struct CachedBadgeDetail {
        let detail: BadgeDetail
        let timestamp: Date
    }
    
    // MARK: - Cache Operations (Usa ESTRATEGIA 1: Dispatcher - 5 puntos)
    // Operaciones de cache usan dispatcher con queue serial para thread-safety
    
    func cacheDetail(badgeId: String, userId: String, detail: BadgeDetail) {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        
        // Dispatcher: ejecutar en background queue
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🧵 [DISPATCHER] Caching detail on background queue...")
            self.cache[key] = CachedBadgeDetail(detail: detail, timestamp: Date())
            
            DispatchQueue.main.async {
                print("💾 [MAIN] Cached badge detail in memory: \(key)")
            }
        }
    }
    
    func getCachedDetail(badgeId: String, userId: String) -> BadgeDetail? {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        
        // Sync read desde queue para thread-safety
        return cacheQueue.sync {
            guard let cached = self.cache[key] else {
                print("❌ No memory cache for: \(key)")
                return nil
            }
            
            let age = Date().timeIntervalSince(cached.timestamp)
            if age > self.cacheExpirationTime {
                print("⏰ Memory cache expired for: \(key)")
                self.cache.removeValue(forKey: key)
                return nil
            }
            
            print("✅ Found valid memory cache for: \(key)")
            return cached.detail
        }
    }
    
    func clearCache(badgeId: String, userId: String) {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            self.cache.removeValue(forKey: key)
            print("🗑️ Cleared memory cache for: \(key)")
        }
    }
    
    func clearAllCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            self.cache.removeAll()
            print("🗑️ Cleared all badge detail memory cache")
        }
    }
    
    // MARK: - Batch Operations (Usa ESTRATEGIA 4: Parallel Tasks - 10 puntos)
    // Operaciones en lote usan tasks paralelos para mejor performance
    
    func cacheMultipleDetails(_ details: [(badgeId: String, userId: String, detail: BadgeDetail)]) async {
        print("🔄 [PARALLEL] Caching multiple details in parallel...")
        
        await withTaskGroup(of: Void.self) { group in
            for item in details {
                group.addTask(priority: .utility) { [weak self] in
                    guard let self = self else { return }
                    
                    let key = self.cacheKey(badgeId: item.badgeId, userId: item.userId)
                    
                    await self.cacheQueue.async {
                        self.cache[key] = CachedBadgeDetail(detail: item.detail, timestamp: Date())
                        print("💾 [TASK] Cached: \(key)")
                    }
                }
            }
        }
        
        print("✅ [PARALLEL] All details cached")
    }
    
    func validateAllCaches() async -> [String: Bool] {
        print("🔄 [PARALLEL] Validating all caches in parallel...")
        
        return await withTaskGroup(of: (String, Bool).self) { group -> [String: Bool] in
            let keys = cacheQueue.sync { Array(self.cache.keys) }
            
            for key in keys {
                group.addTask(priority: .utility) { [weak self] in
                    guard let self = self else { return (key, false) }
                    
                    let isValid = await self.cacheQueue.sync {
                        guard let cached = self.cache[key] else { return false }
                        let age = Date().timeIntervalSince(cached.timestamp)
                        return age <= self.cacheExpirationTime
                    }
                    
                    return (key, isValid)
                }
            }
            
            var results: [String: Bool] = [:]
            for await (key, isValid) in group {
                results[key] = isValid
            }
            
            print("✅ [PARALLEL] Validation completed: \(results.count) entries")
            return results
        }
    }
    
    // MARK: - Helper
    
    private func cacheKey(badgeId: String, userId: String) -> String {
        return "\(userId)_\(badgeId)"
    }
    
    // MARK: - Debug
    
    func debugCache(badgeId: String, userId: String) {
        let key = cacheKey(badgeId: badgeId, userId: userId)
        
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let cached = self.cache[key] {
                let age = Date().timeIntervalSince(cached.timestamp)
                print("🔍 Cache status for \(key): exists, age: \(age)s")
            } else {
                print("🔍 Cache status for \(key): not found")
            }
        }
    }
}
