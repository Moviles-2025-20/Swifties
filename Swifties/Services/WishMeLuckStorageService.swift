//
//  WishMeLuckStorageService.swift
//  Swifties
//
//  Layer 2: Realm Storage for Wish Me Luck
//

import Foundation
import RealmSwift

class WishMeLuckStorageService {
    static let shared = WishMeLuckStorageService()
    
    private var realm: Realm?
    private let storageExpirationHours: Double = 24.0 // 24 hours
    
    private init() {
        setupRealm()
    }
    
    private func setupRealm() {
        do {
            let config = Realm.Configuration(
                schemaVersion: 1,
                migrationBlock: { migration, oldSchemaVersion in
                    if oldSchemaVersion < 1 {
                        // Handle migrations if needed
                    }
                }
            )
            
            Realm.Configuration.defaultConfiguration = config
            realm = try Realm()
            print("✅ Realm initialized for Wish Me Luck")
        } catch {
            print("❌ Error initializing Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save to Realm
    
    func saveDaysSinceLastWished(userId: String, days: Int, lastWishedDate: Date?) {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return
        }
        
        let realmData = RealmWishMeLuckData(
            userId: userId,
            daysSinceLastWished: days,
            lastWishedDate: lastWishedDate
        )
        
        do {
            try realm.write {
                realm.add(realmData, update: .modified)
            }
            print("💾 Saved to Realm: \(userId) - \(days) days")
        } catch {
            print("❌ Error saving to Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load from Realm
    
    func loadDaysSinceLastWished(userId: String) -> (days: Int, lastWishedDate: Date?)? {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return nil
        }
        
        guard let realmData = realm.object(ofType: RealmWishMeLuckData.self, forPrimaryKey: userId) else {
            print("❌ No data found in Realm for: \(userId)")
            return nil
        }
        
        // Check expiration
        let hoursElapsed = Date().timeIntervalSince(realmData.lastUpdated) / 3600
        print("📦 Realm data age: \(String(format: "%.1f", hoursElapsed)) hours")
        
        if hoursElapsed > storageExpirationHours {
            print("⏰ Realm data expired")
            deleteDaysSinceLastWished(userId: userId)
            return nil
        }
        
        print("✅ Loaded from Realm: \(userId) - \(realmData.daysSinceLastWished) days")
        return (days: realmData.daysSinceLastWished, lastWishedDate: realmData.lastWishedDate)
    }
    
    // MARK: - Delete
    
    func deleteDaysSinceLastWished(userId: String) {
        guard let realm = realm else { return }
        
        if let object = realm.object(ofType: RealmWishMeLuckData.self, forPrimaryKey: userId) {
            do {
                try realm.write {
                    realm.delete(object)
                }
                print("🗑️ Deleted from Realm: \(userId)")
            } catch {
                print("❌ Error deleting from Realm: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllStorage() {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                let allWishMeLuckData = realm.objects(RealmWishMeLuckData.self)
                realm.delete(allWishMeLuckData)
            }
            print("🗑️ All Wish Me Luck Realm data cleared")
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
        
        print("\n=== DEBUG WISH ME LUCK REALM ===")
        print("User ID: \(userId)")
        
        if let data = realm.object(ofType: RealmWishMeLuckData.self, forPrimaryKey: userId) {
            let hoursElapsed = Date().timeIntervalSince(data.lastUpdated) / 3600
            print("Found: YES")
            print("Last Updated: \(data.lastUpdated)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
            print("Days Since Last Wished: \(data.daysSinceLastWished)")
            print("Last Wished Date: \(data.lastWishedDate?.description ?? "nil")")
        } else {
            print("Found: NO")
        }
        
        let allObjects = realm.objects(RealmWishMeLuckData.self)
        print("Total stored users: \(allObjects.count)")
        print("====================================\n")
    }
}