//
//  BadgeStorageService.swift
//  Swifties
//
//  Layer 2: Hybrid Storage (UserDefaults + SQLite via DatabaseManager)
//  HYBRID STRATEGY:
//  - UserDefaults: Metadata, timestamps, quick access data
//  - SQLite (via DatabaseManager): Full badge data, relationships, complex queries
//

import Foundation
import SQLite

class BadgeStorageService {
    static let shared = BadgeStorageService()
    
    private let databaseManager = DatabaseManager.shared
    private let storageExpirationHours: Double = 24.0
    
    // UserDefaults keys
    private let lastUpdateKey = "badge_last_update_"
    private let cachedCountKey = "badge_cached_count_"
    private let unlockedCountKey = "badge_unlocked_count_"
    private let userPreferencesKey = "badge_user_preferences_"
    
    private init() {
        setupTables()
    }
    
    // MARK: - SQLite Setup via DatabaseManager
    
    private func setupTables() {
        guard let db = databaseManager.connection else {
            print("❌ Cannot setup badge tables: database not available")
            return
        }
        
        do {
            try BadgesTable.createTable(in: db)
            try BadgesTable.createIndexes(in: db)
            
            try UserBadgesTable.createTable(in: db)
            try UserBadgesTable.createIndexes(in: db)
            
            #if DEBUG
            print("✅ Badge tables initialized via DatabaseManager")
            #endif
        } catch {
            print("❌ Error setting up badge tables: \(error)")
        }
    }
    
    // MARK: - Save (Hybrid Strategy)
    
    func saveBadges(userId: String, badges: [Badge], userBadges: [UserBadge], completion: (() -> Void)? = nil) {
        print("💾 [HYBRID] Starting hybrid save for user: \(userId)")
        
        // PASO 1: Guardar metadata en UserDefaults (rápido, main thread)
        saveMetadataToUserDefaults(userId: userId, badges: badges, userBadges: userBadges)
        
        // PASO 2: Guardar datos completos en SQLite via DatabaseManager (background)
        databaseManager.executeTransaction { db in
            try self.saveBadgesToSQLite(db: db, userId: userId, badges: badges)
            try self.saveUserBadgesToSQLite(db: db, userId: userId, userBadges: userBadges)
        } completion: { result in
            switch result {
            case .success:
                print("✅ [SQLITE] Saved \(badges.count) badges via DatabaseManager")
            case .failure(let error):
                print("❌ [SQLITE] Error saving badges: \(error)")
            }
            completion?()
        }
    }
    
    private func saveMetadataToUserDefaults(userId: String, badges: [Badge], userBadges: [UserBadge]) {
        let defaults = UserDefaults.standard
        
        defaults.set(Date().timeIntervalSince1970, forKey: lastUpdateKey + userId)
        defaults.set(badges.count, forKey: cachedCountKey + userId)
        
        let unlockedCount = userBadges.filter { $0.isUnlocked }.count
        defaults.set(unlockedCount, forKey: unlockedCountKey + userId)
        
        let unlockedIds = userBadges.filter { $0.isUnlocked }.map { $0.badgeId }
        defaults.set(unlockedIds, forKey: "unlocked_badge_ids_\(userId)")
        
        defaults.synchronize()
        print("✅ [USERDEFAULTS] Saved metadata for \(badges.count) badges")
    }
    
    private func saveBadgesToSQLite(db: Connection, userId: String, badges: [Badge]) throws {
        // Limpiar badges antiguos del usuario
        try db.run(BadgesTable.table.filter(BadgesTable.userId == userId).delete())
        
        // Insertar nuevos badges
        for badge in badges {
            try db.run(BadgesTable.table.insert(
                BadgesTable.id <- badge.id,
                BadgesTable.userId <- userId,
                BadgesTable.name <- badge.name,
                BadgesTable.badgeDescription <- badge.description,
                BadgesTable.icon <- badge.icon,
                BadgesTable.rarity <- badge.rarity.rawValue,
                BadgesTable.criteriaType <- badge.criteriaType.rawValue,
                BadgesTable.criteriaValue <- badge.criteriaValue,
                BadgesTable.isSecret <- badge.isSecret,
                BadgesTable.createdAt <- badge.createdAt,
                BadgesTable.updatedAt <- badge.updatedAt
            ))
        }
    }
    
    private func saveUserBadgesToSQLite(db: Connection, userId: String, userBadges: [UserBadge]) throws {
        // Limpiar progreso antiguo
        try db.run(UserBadgesTable.table.filter(UserBadgesTable.userId == userId).delete())
        
        // Insertar progreso
        for userBadge in userBadges {
            let earnedAtTimestamp = userBadge.earnedAt?.timeIntervalSince1970
            
            try db.run(UserBadgesTable.table.insert(
                UserBadgesTable.id <- userBadge.id,
                UserBadgesTable.userId <- userId,
                UserBadgesTable.badgeId <- userBadge.badgeId,
                UserBadgesTable.progress <- userBadge.progress,
                UserBadgesTable.isUnlocked <- userBadge.isUnlocked,
                UserBadgesTable.earnedAt <- earnedAtTimestamp,
                UserBadgesTable.lastUpdated <- Date().timeIntervalSince1970
            ))
        }
    }
    
    // MARK: - Load (Hybrid Strategy)
    
    func loadBadges(userId: String, completion: @escaping ((badges: [Badge], userBadges: [UserBadge])?) -> Void) {
        print("📦 [HYBRID] Loading badges for user: \(userId)")
        
        // PASO 1: Validación rápida con UserDefaults
        guard isDataValid(userId: userId) else {
            print("⏰ UserDefaults indicates expired data")
            completion(nil)
            return
        }
        
        // PASO 2: Cargar datos completos de SQLite
        loadFromSQLite(userId: userId, completion: completion)
    }
    
    private func isDataValid(userId: String) -> Bool {
        let defaults = UserDefaults.standard
        
        guard let lastUpdate = defaults.object(forKey: lastUpdateKey + userId) as? TimeInterval else {
            print("❌ No timestamp in UserDefaults")
            return false
        }
        
        let hoursElapsed = (Date().timeIntervalSince1970 - lastUpdate) / 3600
        print("📦 Badge data age: \(String(format: "%.1f", hoursElapsed)) hours")
        
        if hoursElapsed > storageExpirationHours {
            print("⏰ Data expired")
            return false
        }
        
        let cachedCount = defaults.integer(forKey: cachedCountKey + userId)
        if cachedCount == 0 {
            print("❌ No cached count in UserDefaults")
            return false
        }
        
        print("✅ UserDefaults validation passed (\(cachedCount) badges)")
        return true
    }
    
    private func loadFromSQLite(userId: String, completion: @escaping ((badges: [Badge], userBadges: [UserBadge])?) -> Void) {
        databaseManager.executeRead { db in
            var badges: [Badge] = []
            var userBadges: [UserBadge] = []
            
            // Cargar badges
            let badgeQuery = BadgesTable.table.filter(BadgesTable.userId == userId)
            for row in try db.prepare(badgeQuery) {
                let badge = Badge(
                    id: row[BadgesTable.id],
                    name: row[BadgesTable.name],
                    description: row[BadgesTable.badgeDescription],
                    icon: row[BadgesTable.icon],
                    rarity: BadgeRarity(rawValue: row[BadgesTable.rarity]) ?? .common,
                    criteriaType: CriteriaType(rawValue: row[BadgesTable.criteriaType]) ?? .eventsAttended,
                    criteriaValue: row[BadgesTable.criteriaValue],
                    isSecret: row[BadgesTable.isSecret],
                    createdAt: row[BadgesTable.createdAt],
                    updatedAt: row[BadgesTable.updatedAt]
                )
                badges.append(badge)
            }
            
            // Cargar user badges
            let userBadgeQuery = UserBadgesTable.table.filter(UserBadgesTable.userId == userId)
            for row in try db.prepare(userBadgeQuery) {
                var earnedAt: Date?
                if let timestamp = row[UserBadgesTable.earnedAt] {
                    earnedAt = Date(timeIntervalSince1970: timestamp)
                }
                
                let userBadge = UserBadge(
                    id: row[UserBadgesTable.id],
                    userId: row[UserBadgesTable.userId],
                    badgeId: row[UserBadgesTable.badgeId],
                    progress: row[UserBadgesTable.progress],
                    isUnlocked: row[UserBadgesTable.isUnlocked],
                    earnedAt: earnedAt
                )
                userBadges.append(userBadge)
            }
            
            return (badges: badges, userBadges: userBadges)
        } completion: { result in
            switch result {
            case .success(let data):
                if data.badges.isEmpty {
                    print("❌ No badges found in SQLite")
                    completion(nil)
                } else {
                    print("✅ Loaded \(data.badges.count) badges and \(data.userBadges.count) user badges from SQLite")
                    completion(data)
                }
            case .failure(let error):
                print("❌ Error loading badges: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Quick Queries (UserDefaults only - ultra fast)
    
    func getQuickStats(userId: String) -> (total: Int, unlocked: Int)? {
        let defaults = UserDefaults.standard
        
        guard isDataValid(userId: userId) else {
            return nil
        }
        
        let total = defaults.integer(forKey: cachedCountKey + userId)
        let unlocked = defaults.integer(forKey: unlockedCountKey + userId)
        
        print("⚡️ [USERDEFAULTS] Quick stats: \(unlocked)/\(total)")
        return (total: total, unlocked: unlocked)
    }
    
    func getUnlockedBadgeIds(userId: String) -> [String] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: "unlocked_badge_ids_\(userId)") ?? []
    }
    
    // MARK: - Advanced SQLite Queries
    
    func getUnlockedBadgesOnly(userId: String, completion: @escaping ([Badge]?) -> Void) {
        databaseManager.executeRead { db in
            var badges: [Badge] = []
            
            let query = BadgesTable.table
                .join(UserBadgesTable.table, on: BadgesTable.id == UserBadgesTable.badgeId)
                .filter(BadgesTable.userId == userId && UserBadgesTable.isUnlocked == true)
            
            for row in try db.prepare(query) {
                let badge = Badge(
                    id: row[BadgesTable.id],
                    name: row[BadgesTable.name],
                    description: row[BadgesTable.badgeDescription],
                    icon: row[BadgesTable.icon],
                    rarity: BadgeRarity(rawValue: row[BadgesTable.rarity]) ?? .common,
                    criteriaType: CriteriaType(rawValue: row[BadgesTable.criteriaType]) ?? .eventsAttended,
                    criteriaValue: row[BadgesTable.criteriaValue],
                    isSecret: row[BadgesTable.isSecret],
                    createdAt: row[BadgesTable.createdAt],
                    updatedAt: row[BadgesTable.updatedAt]
                )
                badges.append(badge)
            }
            
            return badges
        } completion: { result in
            switch result {
            case .success(let badges):
                completion(badges.isEmpty ? nil : badges)
            case .failure(let error):
                print("❌ Error getting unlocked badges: \(error)")
                completion(nil)
            }
        }
    }
    
    func getBadgesByRarity(userId: String, rarity: BadgeRarity, completion: @escaping ([Badge]?) -> Void) {
        databaseManager.executeRead { db in
            var badges: [Badge] = []
            
            let query = BadgesTable.table
                .filter(BadgesTable.userId == userId && BadgesTable.rarity == rarity.rawValue)
            
            for row in try db.prepare(query) {
                let badge = Badge(
                    id: row[BadgesTable.id],
                    name: row[BadgesTable.name],
                    description: row[BadgesTable.badgeDescription],
                    icon: row[BadgesTable.icon],
                    rarity: rarity,
                    criteriaType: CriteriaType(rawValue: row[BadgesTable.criteriaType]) ?? .eventsAttended,
                    criteriaValue: row[BadgesTable.criteriaValue],
                    isSecret: row[BadgesTable.isSecret],
                    createdAt: row[BadgesTable.createdAt],
                    updatedAt: row[BadgesTable.updatedAt]
                )
                badges.append(badge)
            }
            
            return badges
        } completion: { result in
            switch result {
            case .success(let badges):
                completion(badges.isEmpty ? nil : badges)
            case .failure(let error):
                print("❌ Error getting badges by rarity: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteBadges(userId: String, completion: (() -> Void)? = nil) {
        print("🗑️ [HYBRID] Deleting badges for user: \(userId)")
        
        // Limpiar UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: lastUpdateKey + userId)
        defaults.removeObject(forKey: cachedCountKey + userId)
        defaults.removeObject(forKey: unlockedCountKey + userId)
        defaults.removeObject(forKey: "unlocked_badge_ids_\(userId)")
        defaults.synchronize()
        
        // Limpiar SQLite via DatabaseManager
        databaseManager.executeTransaction { db in
            try db.run(BadgesTable.table.filter(BadgesTable.userId == userId).delete())
            try db.run(UserBadgesTable.table.filter(UserBadgesTable.userId == userId).delete())
        } completion: { result in
            switch result {
            case .success:
                print("✅ [SQLITE] Deleted all badges for user")
            case .failure(let error):
                print("❌ [SQLITE] Error deleting badges: \(error)")
            }
            completion?()
        }
    }
    
    func clearAllStorage(completion: (() -> Void)? = nil) {
        print("🗑️ [HYBRID] Clearing all storage")
        
        // Limpiar UserDefaults
        let defaults = UserDefaults.standard
        let dict = defaults.dictionaryRepresentation()
        for key in dict.keys {
            if key.contains("badge_") {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
        
        // Limpiar SQLite via DatabaseManager
        databaseManager.executeTransaction { db in
            try db.run(BadgesTable.table.delete())
            try db.run(UserBadgesTable.table.delete())
        } completion: { result in
            switch result {
            case .success:
                print("✅ [SQLITE] All badge data cleared")
            case .failure(let error):
                print("❌ [SQLITE] Error clearing data: \(error)")
            }
            completion?()
        }
    }
    
    // MARK: - Debug
    
    func debugStorage(userId: String) {
        print("\n=== DEBUG HYBRID STORAGE ===")
        print("User ID: \(userId)")
        
        // Debug UserDefaults
        let defaults = UserDefaults.standard
        if let lastUpdate = defaults.object(forKey: lastUpdateKey + userId) as? TimeInterval {
            let date = Date(timeIntervalSince1970: lastUpdate)
            let hoursElapsed = (Date().timeIntervalSince1970 - lastUpdate) / 3600
            print("\n[USERDEFAULTS]")
            print("Last Updated: \(date)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
            print("Cached Count: \(defaults.integer(forKey: cachedCountKey + userId))")
            print("Unlocked Count: \(defaults.integer(forKey: unlockedCountKey + userId))")
        } else {
            print("\n[USERDEFAULTS] No data found")
        }
        
        // Debug SQLite via DatabaseManager
        databaseManager.executeRead { db in
            let badgeCount = try db.scalar(BadgesTable.table.filter(BadgesTable.userId == userId).count)
            let userBadgeCount = try db.scalar(UserBadgesTable.table.filter(UserBadgesTable.userId == userId).count)
            
            return (badges: badgeCount, userBadges: userBadgeCount)
        } completion: { result in
            switch result {
            case .success(let counts):
                print("\n[SQLITE]")
                print("Total Badges: \(counts.badges)")
                print("Total User Badges: \(counts.userBadges)")
            case .failure(let error):
                print("\n[SQLITE] Error: \(error)")
            }
            
            print("============================\n")
        }
    }
}

// MARK: - Badge Table Definitions

struct BadgesTable {
    static let table = Table("badges")
    
    static let id = Expression<String>("id")
    static let userId = Expression<String>("user_id")
    static let name = Expression<String>("name")
    static let badgeDescription = Expression<String>("description")
    static let icon = Expression<String>("icon")
    static let rarity = Expression<String>("rarity")
    static let criteriaType = Expression<String>("criteria_type")
    static let criteriaValue = Expression<Int>("criteria_value")
    static let isSecret = Expression<Bool>("is_secret")
    static let createdAt = Expression<String>("created_at")
    static let updatedAt = Expression<String>("updated_at")
    
    static func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id)
            t.column(userId)
            t.column(name)
            t.column(badgeDescription)
            t.column(icon)
            t.column(rarity)
            t.column(criteriaType)
            t.column(criteriaValue)
            t.column(isSecret)
            t.column(createdAt)
            t.column(updatedAt)
            
            t.primaryKey(id, userId)
        })
    }
    
    static func createIndexes(in db: Connection) throws {
        try db.run("CREATE INDEX IF NOT EXISTS idx_badges_user_id ON badges(user_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_badges_rarity ON badges(rarity)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_badges_criteria ON badges(criteria_type)")
    }
}

struct UserBadgesTable {
    static let table = Table("user_badges")
    
    static let id = Expression<String>("id")
    static let userId = Expression<String>("user_id")
    static let badgeId = Expression<String>("badge_id")
    static let progress = Expression<Int>("progress")
    static let isUnlocked = Expression<Bool>("is_unlocked")
    static let earnedAt = Expression<Double?>("earned_at")
    static let lastUpdated = Expression<Double>("last_updated")
    
    static func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(userId)
            t.column(badgeId)
            t.column(progress)
            t.column(isUnlocked)
            t.column(earnedAt)
            t.column(lastUpdated)
            
            t.foreignKey(badgeId, references: BadgesTable.table, BadgesTable.id)
        })
    }
    
    static func createIndexes(in db: Connection) throws {
        try db.run("CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id ON user_badges(badge_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_user_badges_unlocked ON user_badges(is_unlocked)")
    }
}
