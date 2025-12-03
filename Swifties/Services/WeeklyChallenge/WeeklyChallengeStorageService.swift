//
//  WeeklyChallengeStorageService.swift
//  Swifties
//
//  Layer 2: Realm Storage for Weekly Challenge - FIXED VERSION
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
    
    // MARK: - Save to Realm (FIXED)
    
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
        
        do {
            try realm.write {
                // FIX: Buscar si ya existe (por userId que es la primary key)
                if let existing = realm.object(ofType: RealmWeeklyChallengeData.self, forPrimaryKey: userId) {
                    // Actualizar existente
                    existing.weekIdentifier = weekId
                    existing.eventData = eventData
                    existing.hasAttended = hasAttended
                    existing.totalChallenges = totalChallenges
                    existing.lastUpdated = Date()
                    
                    // Actualizar chartData
                    existing.chartData.removeAll()
                    for data in chartData {
                        let realmChartData = RealmChartData()
                        realmChartData.label = data.label
                        realmChartData.count = data.count
                        existing.chartData.append(realmChartData)
                    }
                    
                    print("💾 Updated in Realm: \(userId) for week \(weekId)")
                } else {
                    // Crear nuevo
                    let realmData = RealmWeeklyChallengeData()
                    realmData.userId = userId
                    realmData.weekIdentifier = weekId
                    realmData.eventData = eventData
                    realmData.hasAttended = hasAttended
                    realmData.totalChallenges = totalChallenges
                    realmData.lastUpdated = Date()
                    
                    for data in chartData {
                        let realmChartData = RealmChartData()
                        realmChartData.label = data.label
                        realmChartData.count = data.count
                        realmData.chartData.append(realmChartData)
                    }
                    
                    realm.add(realmData)
                    print("💾 Saved to Realm: \(userId) for week \(weekId)")
                }
            }
        } catch {
            print("❌ Error saving to Realm: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load from Realm (FIXED)
    
    func loadChallenge(userId: String) -> (event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData])? {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return nil
        }
        
        let weekId = Date().weekIdentifier()
        
        print("🔍 Looking for Realm data for user: \(userId), week: \(weekId)")
        
        guard let realmData = realm.object(ofType: RealmWeeklyChallengeData.self, forPrimaryKey: userId) else {
            print("❌ No data found in Realm for user: \(userId)")
            return nil
        }
        
        // Check if data is for current week
        if realmData.weekIdentifier != weekId {
            print("⚠️ Stored data is from a different week: \(realmData.weekIdentifier) vs current: \(weekId)")
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
        
        print("✅ Loaded from Realm for user: \(userId)")
        print("   - Event: \(event?.name ?? "nil")")
        print("   - Has Attended: \(realmData.hasAttended)")
        print("   - Total Challenges: \(realmData.totalChallenges)")
        print("   - Chart Data Points: \(chartData.count)")
        
        return (event: event, hasAttended: realmData.hasAttended, totalChallenges: realmData.totalChallenges, chartData: chartData)
    }
    
    // MARK: - Cleanup (NEW)
    
    private func cleanupOldWeekData(userId: String, currentWeek: String) {
        guard let realm = realm else { return }
        
        do {
            let allUserData = realm.objects(RealmWeeklyChallengeData.self).filter("userId == %@", userId)
            
            try realm.write {
                for data in allUserData {
                    if data.weekIdentifier != currentWeek {
                        print("🗑️ Deleting old week data for week: \(data.weekIdentifier)")
                        realm.delete(data)
                    }
                }
            }
        } catch {
            print("❌ Error cleaning up old data: \(error.localizedDescription)")
        }
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
        
        let weekId = Date().weekIdentifier()
        
        print("\n=== DEBUG WEEKLY CHALLENGE REALM ===")
        print("User ID: \(userId)")
        print("Current Week: \(weekId)")
        
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
            print("Is Current Week: \(data.weekIdentifier == weekId ? "YES ✅" : "NO ❌")")
            print("Is Expired: \(hoursElapsed > storageExpirationHours ? "YES ⏰" : "NO ✅")")
        } else {
            print("Found: NO")
            
            // Mostrar todos los datos del usuario
            let allUserData = realm.objects(RealmWeeklyChallengeData.self).filter("userId == %@", userId)
            print("Total records for user: \(allUserData.count)")
            for data in allUserData {
                print("  - Week: \(data.weekIdentifier), Updated: \(data.lastUpdated)")
            }
        }
        
        let allObjects = realm.objects(RealmWeeklyChallengeData.self)
        print("Total stored records: \(allObjects.count)")
        print("====================================\n")
    }
}

// MARK: - NOTA: Las clases Realm ya deben estar definidas en tu archivo original
// Si no existen, agrégalas. Si ya existen, actualízalas para que incluyan:
//
// class RealmWeeklyChallengeData: Object {
//     @Persisted(primaryKey: true) var userId: String = ""
//     @Persisted var weekIdentifier: String = ""
//     @Persisted var eventData: Data?
//     @Persisted var hasAttended: Bool = false
//     @Persisted var totalChallenges: Int = 0
//     @Persisted var chartData: List<RealmChartData>
//     @Persisted var lastUpdated: Date = Date()
// }
//
// class RealmChartData: Object {
//     @Persisted var label: String = ""
//     @Persisted var count: Int = 0
// }
