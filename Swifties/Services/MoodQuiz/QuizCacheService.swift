//
//  QuizCacheService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/11/25.
//


import Foundation

class QuizCacheService {
    static let shared = QuizCacheService()
    
    private let cache = NSCache<NSString, CachedQuizResultWrapper>()
    private var cacheTimestamps: [String: Date] = [:]
    private let cacheExpirationMinutes = 60.0 // 1 hour
    
    private init() {
        // Calculate cache size dynamically based on available memory
        let maxMemory = ProcessInfo.processInfo.physicalMemory
        let cacheSize = Int(maxMemory / 1024 / 8) // Use 1/8th of available memory for cache
        
        cache.countLimit = 10 // Limit to 10 users
        cache.totalCostLimit = cacheSize
        
        print("Quiz cache initialized with limit: \(cacheSize) bytes")
    }
    
    // MARK: - Cache Quiz Result
    
    func cacheQuizResult(userId: String, result: QuizResult, userQuizResult: UserQuizResult) {
        let wrapper = CachedQuizResultWrapper(
            quizResult: result,
            userQuizResult: userQuizResult
        )
        
        let key = userId as NSString
        cache.setObject(wrapper, forKey: key)
        cacheTimestamps[userId] = Date()
        
        print("[SAVEED]] Cached quiz result for user: \(userId) - Category: \(result.moodCategory)")
    }
    
    // MARK: - Get Cached Result
    
    func getCachedResult(userId: String) -> CachedQuizResultWrapper? {
        // Check if cache has expired
        if let lastCache = cacheTimestamps[userId],
           Date().timeIntervalSince(lastCache) > cacheExpirationMinutes * 60 {
            clearCache(userId: userId)
            return nil
        }
        
        let key = userId as NSString
        guard let wrapper = cache.object(forKey: key) else {
            print("❌ No cached quiz result for user: \(userId)")
            return nil
        }
        
        let age = cacheTimestamps[userId].map { Date().timeIntervalSince($0) / 60 } ?? 0
        print("✅ Cache hit for quiz result (age: \(String(format: "%.1f", age)) minutes)")
        return wrapper
    }
    
    // MARK: - Clear Cache
    
    func clearCache(userId: String) {
        let key = userId as NSString
        cache.removeObject(forKey: key)
        cacheTimestamps.removeValue(forKey: userId)
        print("XXXXXX Cleared quiz result cache for user: \(userId)")
    }
    
    func clearAllCache() {
        cache.removeAllObjects()
        cacheTimestamps.removeAll()
        print("XXXXX All quiz result caches cleared")
    }
    
    // MARK: - Cache Age
    
    func getCacheAge(userId: String) -> TimeInterval? {
        guard let lastCache = cacheTimestamps[userId] else { return nil }
        return Date().timeIntervalSince(lastCache)
    }
    
    // MARK: - Debug
    
    func debugCache(userId: String) {
        print("\n=== DEBUG QUIZ RESULT CACHE ===")
        print("User ID: \(userId)")
        
        let key = userId as NSString
        if let wrapper = cache.object(forKey: key),
           let lastCache = cacheTimestamps[userId] {
            let age = Date().timeIntervalSince(lastCache) / 60
            let isValid = age <= cacheExpirationMinutes
            
            print("Found: YES")
            print("Age: \(String(format: "%.1f", age)) minutes")
            print("Result Category: \(wrapper.quizResult.moodCategory)")
            print("Is Tied: \(wrapper.quizResult.isTied)")
            print("Valid: \(isValid)")
        } else {
            print("Found: NO")
        }
        
        print("Total cached items: \(cacheTimestamps.count)")
        print("==================================\n")
    }
}

// MARK: - Cached Result Wrapper

/// Wrapper class to store quiz results in NSCache
/// NSCache requires reference types (classes), not value types (structs)
class CachedQuizResultWrapper {
    let quizResult: QuizResult
    let userQuizResult: UserQuizResult
    let timestamp: Date
    
    init(quizResult: QuizResult, userQuizResult: UserQuizResult) {
        self.quizResult = quizResult
        self.userQuizResult = userQuizResult
        self.timestamp = Date()
    }
}
