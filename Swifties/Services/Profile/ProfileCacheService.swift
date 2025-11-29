import Foundation

final class ProfileCacheService {
    static let shared = ProfileCacheService()

    private let cache = NSCache<NSString, CachedProfileWrapper>()
    private let cacheKey: NSString = "profile_cache_key"
    private var lastCacheTime: Date?
    private let cacheExpirationMinutes: Double = 5

    private init() {
        cache.countLimit = 1
        cache.totalCostLimit = 1024 * 1024 * 2 // 2 MB
    }

    func getCachedProfile() -> UserModel? {
        if let last = lastCacheTime, Date().timeIntervalSince(last) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        return cache.object(forKey: cacheKey)?.profile
    }

    func cacheProfile(_ profile: UserModel) {
        cache.setObject(CachedProfileWrapper(profile: profile), forKey: cacheKey)
        lastCacheTime = Date()
    }

    func clearCache() {
        cache.removeAllObjects()
        lastCacheTime = nil
    }
}

final class CachedProfileWrapper: NSObject {
    let profile: UserModel
    init(profile: UserModel) { self.profile = profile }
}
