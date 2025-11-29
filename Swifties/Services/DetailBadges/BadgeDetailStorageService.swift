//
//  BadgeDetailStorageService.swift
//  Swifties
//
//  Layer 2: Realm/SQLite Storage for Badge Detail
//

import Foundation
import RealmSwift

class BadgeDetailStorageService {
    static let shared = BadgeDetailStorageService()
    
    private var realm: Realm?
    
    private init() {
        setupRealm()
    }
    
    private func setupRealm() {
        do {
            let config = Realm.Configuration(
                schemaVersion: 2,
                migrationBlock: { migration, oldSchemaVersion in
                    if oldSchemaVersion < 2 {
                        // Handle migration if needed
                    }
                }
            )
            realm = try Realm(configuration: config)
            print("✅ Realm initialized for Badge Detail Storage")
        } catch {
            print("❌ Error initializing Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Detail
    
    func saveDetail(badgeId: String, userId: String, detail: BadgeDetail) {
        guard let realm = realm else {
            print("❌ Realm not available")
            return
        }
        
        do {
            let realmDetail = RealmBadgeDetail(detail: detail, userId: userId)
            
            try realm.write {
                realm.add(realmDetail, update: .modified)
            }
            
            print("✅ Saved badge detail to Realm: \(badgeId)")
        } catch {
            print("❌ Error saving badge detail: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Detail
    
    func loadDetail(badgeId: String, userId: String) -> BadgeDetail? {
        guard let realm = realm else {
            print("❌ Realm not available")
            return nil
        }
        
        let key = "\(userId)_\(badgeId)"
        
        guard let realmDetail = realm.object(ofType: RealmBadgeDetail.self, forPrimaryKey: key) else {
            print("❌ No stored detail for: \(key)")
            return nil
        }
        
        // Check if cache is too old (7 days)
        let age = Date().timeIntervalSince(realmDetail.cachedAt)
        if age > 604800 { // 7 days
            print("⏰ Stored detail expired for: \(key)")
            deleteDetail(badgeId: badgeId, userId: userId)
            return nil
        }
        
        print("✅ Loaded badge detail from Realm: \(key)")
        return realmDetail.toBadgeDetail()
    }
    
    // MARK: - Delete Detail
    
    func deleteDetail(badgeId: String, userId: String) {
        guard let realm = realm else { return }
        
        let key = "\(userId)_\(badgeId)"
        
        do {
            try realm.write {
                if let detail = realm.object(ofType: RealmBadgeDetail.self, forPrimaryKey: key) {
                    realm.delete(detail)
                    print("🗑️ Deleted badge detail from Realm: \(key)")
                }
            }
        } catch {
            print("❌ Error deleting badge detail: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Debug
    
    func debugStorage(badgeId: String, userId: String) {
        guard let realm = realm else {
            print("🔍 Realm not available")
            return
        }
        
        let key = "\(userId)_\(badgeId)"
        
        if let detail = realm.object(ofType: RealmBadgeDetail.self, forPrimaryKey: key) {
            let age = Date().timeIntervalSince(detail.cachedAt)
            print("🔍 Storage status for \(key): exists, cached \(age)s ago")
        } else {
            print("🔍 Storage status for \(key): not found")
        }
    }
}
