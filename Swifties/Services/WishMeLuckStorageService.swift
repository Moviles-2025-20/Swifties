//
//  WishMeLuckStorageService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation
import RealmSwift

class WishMeLuckStorageService {
    static let shared = WishMeLuckStorageService()
    
    private var realm: Realm?
    private let storageExpirationHours: Double = 24.0 // 24 hours
    
    // Serial queue for Realm operations (Realm requires thread-confined access)
    private let realmQueue = DispatchQueue(label: "com.swifties.realmQueue", qos: .userInitiated)
    
    private init() {
        setupRealm()
    }
    
    private func setupRealm() {
        // Setup Realm synchronously to ensure it's ready
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
            self.realm = try Realm()
            print("✅ Realm initialized for Wish Me Luck")
        } catch {
            print("❌ Error initializing Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save to Realm
    
    func saveDaysSinceLastWished(userId: String, days: Int, lastWishedDate: Date?) {
        // Realm operations on dedicated queue
        realmQueue.async { [weak self] in
            guard let _ = self else { return }
            
            // Get Realm instance on this thread
            guard let realm = try? Realm() else {
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
    }
    
    // MARK: - Load from Realm (Async with GCD)
    
    func loadDaysSinceLastWished(userId: String) async -> (days: Int, lastWishedDate: Date?)? {
        return await withCheckedContinuation { continuation in
            // Read from Realm on background queue
            realmQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Get Realm instance on this thread
                guard let realm = try? Realm() else {
                    print("❌ Realm not initialized")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let realmData = realm.object(ofType: RealmWishMeLuckData.self, forPrimaryKey: userId) else {
                    print("❌ No data found in Realm for: \(userId)")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Check expiration on background thread
                let hoursElapsed = Date().timeIntervalSince(realmData.lastUpdated) / 3600
                print("📦 Realm data age: \(String(format: "%.1f", hoursElapsed)) hours")
                
                if hoursElapsed > self.storageExpirationHours {
                    print("⏰ Realm data expired")
                    self.deleteDaysSinceLastWishedInternal(userId: userId, realm: realm)
                    continuation.resume(returning: nil)
                    return
                }
                
                let result = (days: realmData.daysSinceLastWished, lastWishedDate: realmData.lastWishedDate)
                print("✅ Loaded from Realm: \(userId) - \(realmData.daysSinceLastWished) days")
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteDaysSinceLastWished(userId: String) {
        realmQueue.async { [weak self] in
            guard let self = self else { return }
            guard let realm = try? Realm() else { return }
            self.deleteDaysSinceLastWishedInternal(userId: userId, realm: realm)
        }
    }
    
    private func deleteDaysSinceLastWishedInternal(userId: String, realm: Realm) {
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
        realmQueue.async { [weak self] in
            guard let _ = self else { return }
            guard let realm = try? Realm() else { return }
            
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
    }
    
    // MARK: - Debug
    
    func debugStorage(userId: String) {
        realmQueue.async { [weak self] in
            guard let _ = self else { return }
            guard let realm = try? Realm() else {
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
}
