//
//  NewsCacheService.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 27/11/25.
//

import Foundation

final class NewsCacheService {
    static let shared = NewsCacheService()

    private let cache = NSCache<NSString, CachedNewsWrapper>()
    private let cacheKey: NSString = "news_cache_key"
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes: Double = 5

    private init() {
        cache.countLimit = 1
        cache.totalCostLimit = 1024 * 1024 * 4 // 4 MB
    }

    func getCachedNews() -> [News]? {
        if let last = lastCacheTime, Date().timeIntervalSince(last) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        return cache.object(forKey: cacheKey)?.news
    }

    func cacheNews(_ news: [News]) {
        cache.setObject(CachedNewsWrapper(news: news), forKey: cacheKey)
        lastCacheTime = Date()
    }

    func clearCache() {
        cache.removeAllObjects()
        lastCacheTime = nil
    }
}

final class CachedNewsWrapper: NSObject {
    let news: [News]
    init(news: [News]) { self.news = news }
}
