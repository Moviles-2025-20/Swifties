//
//  WeeklyChallengeStorageService.swift
//  Swifties
//
//  Layer 2: Realm Storage for Weekly Challenge
//

import Foundation
import RealmSwift

class WeeklyChallengeStorageService {
    static let shared = WeeklyChallengeStorageService()
    
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
            print("✅ Realm initialized for Weekly Challenge")
        } catch {
            print("❌ Error initializing Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save to Realm
    
    func saveChallenge(userId: String, event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData]) {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return
        }
        
        let weekId = Date().weekIdentifier()
        
        // Serialize Event
        var eventData: Data?
        if let event = event {
            let codableEvent = event.toCodable()
            eventData = try? JSONEncoder().encode(codableEvent)
        }
        
        let realmData = RealmWeeklyChallengeData(
            userId: userId,
            weekIdentifier: weekId,
            eventData: eventData,
            hasAttended: hasAttended,
            totalChallenges: totalChallenges,
            chartData: chartData
        )
        
        do {
            try realm.write {
                realm.add(realmData, update: .modified)
            }
            print("💾 Saved to Realm: \(userId)_\(weekId)")
        } catch {
            print("❌ Error saving to Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load from Realm
    
    func loadChallenge(userId: String) -> (event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData])? {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return nil
        }
        
        let weekId = Date().weekIdentifier()
        
        guard let realmData = realm.object(ofType: RealmWeeklyChallengeData.self, forPrimaryKey: userId) else {
            print("❌ No data found in Realm for: \(userId)")
            return nil
        }
        
        // Check if data is for current week
        if realmData.weekIdentifier != weekId {
            print("⚠️ Stored data is from a different week: \(realmData.weekIdentifier)")
            deleteChallenge(userId: userId)
            return nil
        }
        
        // Check expiration
        let hoursElapsed = Date().timeIntervalSince(realmData.lastUpdated) / 3600
        print("📦 Realm data age: \(String(format: "%.1f", hoursElapsed)) hours")
        
        if hoursElapsed > storageExpirationHours {
            print("⏰ Realm data expired")
            deleteChallenge(userId: userId)
            return nil
        }
        
        // Deserialize Event
        var event: Event?
        if let eventData = realmData.eventData {
            if let codableEvent = try? JSONDecoder().decode(CodableEvent.self, from: eventData) {
                event = Event.from(codable: codableEvent)
            }
        }
        
        // Convert Realm List to Array
        let chartData = Array(realmData.chartData.map { WeeklyChallengeChartData(label: $0.label, count: $0.count) })
        
        print("✅ Loaded from Realm: \(userId)_\(weekId)")
        return (event: event, hasAttended: realmData.hasAttended, totalChallenges: realmData.totalChallenges, chartData: chartData)
    }
    
    // MARK: - Delete
    
    func deleteChallenge(userId: String) {
        guard let realm = realm else { return }
        
        if let object = realm.object(ofType: RealmWeeklyChallengeData.self, forPrimaryKey: userId) {
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
                realm.deleteAll()
            }
            print("🗑️ All Realm data cleared")
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
        
        print("\n=== DEBUG WEEKLY CHALLENGE REALM ===")
        print("User ID: \(userId)")
        print("Current Week: \(Date().weekIdentifier())")
        
        if let data = realm.object(ofType: RealmWeeklyChallengeData.self, forPrimaryKey: userId) {
            let hoursElapsed = Date().timeIntervalSince(data.lastUpdated) / 3600
            print("Found: YES")
            print("Week ID: \(data.weekIdentifier)")
            print("Last Updated: \(data.lastUpdated)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
            print("Has Attended: \(data.hasAttended)")
            print("Total Challenges: \(data.totalChallenges)")
            print("Chart Data Points: \(data.chartData.count)")
            print("Event Data Size: \(data.eventData?.count ?? 0) bytes")
        } else {
            print("Found: NO")
        }
        
        let allObjects = realm.objects(RealmWeeklyChallengeData.self)
        print("Total stored users: \(allObjects.count)")
        print("====================================\n")
    }
}
