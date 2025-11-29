//
//  RecommendationCacheService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation

class RecommendationCacheService {
    static let shared = RecommendationCacheService()
    
    private let cache = NSCache<NSString, CachedRecommendationWrapper>()
    private let cacheKey = "recommendations_cache_key" as NSString
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes = 60.0 // 1 hour for recommendations
    
    private init() {
        // Calculate cache size dynamically based on available memory
        let maxMemory = ProcessInfo.processInfo.physicalMemory
        let cacheSize = Int(maxMemory / 1024 / 8) // Use 1/8th of available memory for cache

        cache.countLimit = 5 // Limit to 5 items
        cache.totalCostLimit = cacheSize
        #if DEBUG
        print("Recommendation cache initialized with limit: \(cacheSize) bytes")
        #endif
    }
    
    func getCachedRecommendations() -> [Event]? {
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        
        guard let wrapper = cache.object(forKey: cacheKey) else {
            return nil
        }
        
        #if DEBUG
        print("Recommendations retrieved from memory cache")
        #endif
        return wrapper.recommendations
    }
    
    func cacheRecommendations(_ recommendations: [Event]) {
        let wrapper = CachedRecommendationWrapper(recommendations: recommendations)
        cache.setObject(wrapper, forKey: cacheKey)
        lastCacheTime = Date()
        #if DEBUG
        print("\(recommendations.count) recommendations saved to memory cache")
        #endif
    }
    
    func clearCache() {
        cache.removeAllObjects()
        lastCacheTime = nil
        #if DEBUG
        print("Recommendations memory cache cleared")
        #endif
    }
    
    func getCacheAge() -> TimeInterval? {
        guard let lastCache = lastCacheTime else { return nil }
        return Date().timeIntervalSince(lastCache)
    }
}

// Wrapper class to store recommendations in NSCache
class CachedRecommendationWrapper {
    let recommendations: [Event]
    init(recommendations: [Event]) {
        self.recommendations = recommendations
    }
}

