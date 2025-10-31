//
//  RecommendationCacheService.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
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
        
        cache.countLimit = 10 // Limit to 10 items
        cache.totalCostLimit = cacheSize
        
        print("Recommendation cache initialized with limit: \(cacheSize) bytes")
    }
    
    func getCachedRecommendations() -> [Event]? {
        // Check if cache has expired
        if let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        
        guard let wrapper = cache.object(forKey: cacheKey) else {
            return nil
        }
        
        print("Recommendations retrieved from memory cache")
        return wrapper.recommendations
    }
    
    func cacheRecommendations(_ recommendations: [Event]) {
        let wrapper = CachedRecommendationWrapper(recommendations: recommendations)
        cache.setObject(wrapper, forKey: cacheKey)
        lastCacheTime = Date()
        print("\(recommendations.count) recommendations saved to memory cache")
    }
    
    func clearCache() {
        cache.removeAllObjects()
        lastCacheTime = nil
        print("Recommendations memory cache cleared")
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