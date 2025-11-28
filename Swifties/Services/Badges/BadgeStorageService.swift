//
//  BadgeStorageService.swift
//  Swifties
//
//  Layer 2: Realm Storage for Badges
//

import Foundation
import RealmSwift

class BadgeStorageService {
    static let shared = BadgeStorageService()
    
    private var realm: Realm?
    private let storageExpirationHours: Double = 24.0 // 24 hours
    
    private init() {
        setupRealm()
    }
    
    private func setupRealm() {
        do {
            let config = Realm.Configuration(
                schemaVersion: 2, // Incrementar si ya tienes versión 1
                migrationBlock: { migration, oldSchemaVersion in
                    if oldSchemaVersion < 2 {
                        // Handle migrations if needed
                    }
                }
            )
            
            Realm.Configuration.defaultConfiguration = config
            realm = try Realm()
            print("✅ Realm initialized for Badges")
        } catch {
            print("❌ Error initializing Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save to Realm
    
    func saveBadges(userId: String, badges: [Badge], userBadges: [UserBadge]) {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return
        }
        
        let realmBadges = List<RealmBadge>()
        badges.forEach { realmBadges.append(RealmBadge(from: $0)) }
        
        let realmUserBadges = List<RealmUserBadge>()
        userBadges.forEach { realmUserBadges.append(RealmUserBadge(from: $0)) }
        
        let cache = RealmBadgeCache()
        cache.userId = userId
        cache.badges = realmBadges
        cache.userBadges = realmUserBadges
        cache.lastUpdated = Date()
        
        do {
            try realm.write {
                realm.add(cache, update: .modified)
            }
            print("💾 Saved \(badges.count) badges to Realm for user: \(userId)")
        } catch {
            print("❌ Error saving to Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load from Realm
    
    // MARK: - Load from Realm

    func loadBadges(userId: String) -> (badges: [Badge], userBadges: [UserBadge])? {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return nil
        }
        
        guard let realmData = realm.object(ofType: RealmBadgeCache.self, forPrimaryKey: userId as AnyObject) else {
            print("❌ No badge data found in Realm for: \(userId)")
            return nil
        }
        
        // Check expiration
        let hoursElapsed = Date().timeIntervalSince(realmData.lastUpdated) / 3600
        print("📦 Realm badge data age: \(String(format: "%.1f", hoursElapsed)) hours")
        
        if hoursElapsed > storageExpirationHours {
            print("⏰ Realm badge data expired")
            deleteBadges(userId: userId)
            return nil
        }
        
        // FIX: Explicitly convert to Array
        let badges = Array(realmData.badges.map { $0.toBadge() })
        let userBadges = Array(realmData.userBadges.map { $0.toUserBadge() })
        
        print("✅ Loaded \(badges.count) badges from Realm for user: \(userId)")
        return (badges: badges, userBadges: userBadges)
    }
    
    // MARK: - Delete
    
    func deleteBadges(userId: String) {
        guard let realm = realm else { return }
        
        if let object = realm.object(ofType: RealmBadgeCache.self, forPrimaryKey: userId) {
            do {
                try realm.write {
                    realm.delete(object)
                }
                print("🗑️ Deleted badges from Realm for user: \(userId)")
            } catch {
                print("❌ Error deleting from Realm: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllStorage() {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                let allBadgeCaches = realm.objects(RealmBadgeCache.self)
                realm.delete(allBadgeCaches)
            }
            print("🗑️ All badge data cleared from Realm")
        } catch {
            print("❌ Error clearing Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug
    
    func debugStorage(userId: String) {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return
        }
        
        print("\n=== DEBUG BADGE REALM ===")
        print("User ID: \(userId)")
        
        if let data = realm.object(ofType: RealmBadgeCache.self, forPrimaryKey: userId) {
            let hoursElapsed = Date().timeIntervalSince(data.lastUpdated) / 3600
            print("Found: YES")
            print("Last Updated: \(data.lastUpdated)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
            print("Badges: \(data.badges.count)")
            print("User Badges: \(data.userBadges.count)")
        } else {
            print("Found: NO")
        }
        
        let allObjects = realm.objects(RealmBadgeCache.self)
        print("Total stored users: \(allObjects.count)")
        print("=========================\n")
    }
}
