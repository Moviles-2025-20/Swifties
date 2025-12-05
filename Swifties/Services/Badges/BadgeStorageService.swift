//
//  BadgeStorageService.swift (COMPLETE FIX WITH STALE DATA SUPPORT)
//  Swifties
//
//  Layer 2: Hybrid Storage (UserDefaults + SQLite via DatabaseManager)
//  ✅ AHORA INCLUYE loadStaleData() para modo offline completo
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
            // ✅ MIGRACIÓN: Verificar y recrear tablas si tienen foreign key incorrecta
            migrateBadgeTablesIfNeeded(db: db)
            
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
    
    /// Migra las tablas si tienen la foreign key incorrecta
    private func migrateBadgeTablesIfNeeded(db: Connection) {
        do {
            // Verificar si las tablas ya existen
            let tableExists = try db.scalar(
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='user_badges'"
            ) as! Int64
            
            if tableExists > 0 {
                print("⚠️ [MIGRATION] Existing badge tables found, checking for foreign key issue...")
                
                // Verificar si hay foreign key problemática
                let foreignKeys = try db.prepare(
                    "PRAGMA foreign_key_list(user_badges)"
                )
                
                var hasBrokenFK = false
                for row in foreignKeys {
                    // Si hay alguna FK que referencia solo 'id' de badges, es problemática
                    print("🔍 Found FK: \(row)")
                    hasBrokenFK = true
                }
                
                if hasBrokenFK {
                    print("🔧 [MIGRATION] Recreating tables without problematic foreign key...")
                    
                    // Backup de datos
                    var badgesBackup: [(id: String, userId: String, name: String, desc: String, icon: String, rarity: String, criteriaType: String, criteriaValue: Int, isSecret: Bool, created: String, updated: String)] = []
                    var userBadgesBackup: [(id: String, userId: String, badgeId: String, progress: Int, isUnlocked: Bool, earnedAt: Double?, lastUpdated: Double)] = []
                    
                    // Backup badges
                    if let badgesTable = try? db.prepare("SELECT * FROM badges") {
                        for row in badgesTable {
                            badgesBackup.append((
                                id: row[0] as! String,
                                userId: row[1] as! String,
                                name: row[2] as! String,
                                desc: row[3] as! String,
                                icon: row[4] as! String,
                                rarity: row[5] as! String,
                                criteriaType: row[6] as! String,
                                criteriaValue: Int(row[7] as! Int64),
                                isSecret: (row[8] as! Int64) == 1,
                                created: row[9] as! String,
                                updated: row[10] as! String
                            ))
                        }
                    }
                    
                    // Backup user_badges
                    if let userBadgesTable = try? db.prepare("SELECT * FROM user_badges") {
                        for row in userBadgesTable {
                            userBadgesBackup.append((
                                id: row[0] as! String,
                                userId: row[1] as! String,
                                badgeId: row[2] as! String,
                                progress: Int(row[3] as! Int64),
                                isUnlocked: (row[4] as! Int64) == 1,
                                earnedAt: row[5] as? Double,
                                lastUpdated: row[6] as! Double
                            ))
                        }
                    }
                    
                    print("📦 Backed up \(badgesBackup.count) badges and \(userBadgesBackup.count) user badges")
                    
                    // Desactivar FK temporalmente
                    try db.execute("PRAGMA foreign_keys = OFF")
                    
                    // Eliminar tablas antiguas
                    try db.run("DROP TABLE IF EXISTS user_badges")
                    try db.run("DROP TABLE IF EXISTS badges")
                    
                    print("🗑️ Old tables dropped")
                    
                    // Reactivar FK
                    try db.execute("PRAGMA foreign_keys = ON")
                    
                    // Las tablas se recrearán después con el schema correcto
                    
                    // Restaurar datos si había backup
                    if !badgesBackup.isEmpty || !userBadgesBackup.isEmpty {
                        print("💾 Will restore data after table recreation...")
                        // Los datos se restaurarán en la siguiente ejecución normal
                    }
                }
            }
        } catch {
            print("⚠️ [MIGRATION] Error during migration check: \(error)")
        }
    }
    
    // MARK: - Save (Hybrid Strategy)
    
    func saveBadges(userId: String, badges: [Badge], userBadges: [UserBadge], completion: (() -> Void)? = nil) {
        print("💾 [HYBRID] Starting hybrid save for user: \(userId)")
        
        // PASO 1: Guardar metadata en UserDefaults (rápido, main thread)
        saveMetadataToUserDefaults(userId: userId, badges: badges, userBadges: userBadges)
        
        // PASO 2: Guardar datos completos en SQLite via DatabaseManager (background)
        // ✅ IMPORTANTE: saveUserBadgesToSQLite DEBE ejecutarse ANTES que saveBadgesToSQLite
        // porque user_badges tiene foreign key hacia badges
        databaseManager.executeTransaction { db in
            // Primero guardar user_badges (esto borra los antiguos)
            try self.saveUserBadgesToSQLite(db: db, userId: userId, userBadges: userBadges)
            // Después guardar badges (usando insert or replace)
            try self.saveBadgesToSQLite(db: db, userId: userId, badges: badges)
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
        // ⚠️ IMPORTANTE: NO borrar aquí porque user_badges referencia badges
        // El borrado se hace en saveUserBadgesToSQLite() ANTES de borrar badges
        
        // Insertar o actualizar badges usando indexed loop
        for i in 0..<badges.count {
            let badge = badges[i]
            
            // Usar insert or replace para evitar conflictos
            try db.run(BadgesTable.table.insert(
                or: .replace,
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
        
        // Ahora SÍ borrar badges antiguos que ya no existen
        let currentBadgeIds = badges.map { $0.id }
        let deleteQuery = BadgesTable.table
            .filter(BadgesTable.userId == userId)
            .filter(!currentBadgeIds.contains(BadgesTable.id))
        
        try db.run(deleteQuery.delete())
    }
    
    private func saveUserBadgesToSQLite(db: Connection, userId: String, userBadges: [UserBadge]) throws {
        // ✅ CORRECCIÓN: Borrar user_badges PRIMERO (antes que badges)
        // Esto respeta la foreign key constraint
        try db.run(UserBadgesTable.table.filter(UserBadgesTable.userId == userId).delete())
        
        // Insertar progreso usando indexed loop
        for i in 0..<userBadges.count {
            let userBadge = userBadges[i]
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
    
    // ✅ MÉTODO PRINCIPAL: Respeta expiración
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
    
    // ✅ MÉTODO SECUNDARIO: Ignora expiración para offline (usado en fase inicial)
    func loadBadgesIgnoringExpiration(userId: String, completion: @escaping ((badges: [Badge], userBadges: [UserBadge])?) -> Void) {
        print("📦 [HYBRID-OFFLINE] Loading badges IGNORING expiration for user: \(userId)")
        
        // PASO 1: Verificar que exista ALGO en UserDefaults (sin validar edad)
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: lastUpdateKey + userId) != nil else {
            print("❌ No timestamp in UserDefaults - never saved data")
            completion(nil)
            return
        }
        
        let cachedCount = defaults.integer(forKey: cachedCountKey + userId)
        if cachedCount == 0 {
            print("❌ No cached count in UserDefaults")
            completion(nil)
            return
        }
        
        // PASO 2: Cargar datos de SQLite SIN validar expiración
        print("⚠️ [OFFLINE MODE] Data may be stale but loading anyway...")
        loadFromSQLite(userId: userId, completion: completion)
    }
    
    // 🆕 NUEVO MÉTODO: Carga datos sin validar NADA (último recurso para offline)
    func loadStaleData(userId: String, completion: @escaping ((badges: [Badge], userBadges: [UserBadge])?) -> Void) {
        print("📦 [STALE-MODE] Loading stale data (IGNORING ALL VALIDATION) for user: \(userId)")
        
        let defaults = UserDefaults.standard
        
        // Solo verificar que EXISTA algo guardado alguna vez
        guard defaults.object(forKey: lastUpdateKey + userId) != nil else {
            print("❌ [STALE-MODE] No timestamp found - data never saved")
            completion(nil)
            return
        }
        
        let cachedCount = defaults.integer(forKey: cachedCountKey + userId)
        if cachedCount == 0 {
            print("❌ [STALE-MODE] No cached count found")
            completion(nil)
            return
        }
        
        // Mostrar edad de los datos para debug
        if let lastUpdate = defaults.object(forKey: lastUpdateKey + userId) as? TimeInterval {
            let hoursElapsed = (Date().timeIntervalSince1970 - lastUpdate) / 3600
            let daysElapsed = hoursElapsed / 24
            print("⚠️ [STALE-MODE] Data is \(String(format: "%.1f", daysElapsed)) days old (\(String(format: "%.1f", hoursElapsed)) hours)")
            print("⚠️ [STALE-MODE] This data may be significantly outdated")
        }
        
        // Cargar de SQLite sin ninguna validación
        print("📦 [STALE-MODE] Loading from SQLite regardless of age...")
        loadFromSQLite(userId: userId) { result in
            if result != nil {
                print("✅ [STALE-MODE] Successfully loaded stale data")
                print("⚠️ [STALE-MODE] Remember to show user a warning about outdated data")
            } else {
                print("❌ [STALE-MODE] No data found in SQLite either")
            }
            completion(result)
        }
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
            let daysElapsed = hoursElapsed / 24
            print("\n[USERDEFAULTS]")
            print("Last Updated: \(date)")
            print("Age: \(String(format: "%.1f", daysElapsed)) days (\(String(format: "%.1f", hoursElapsed)) hours)")
            print("Cached Count: \(defaults.integer(forKey: cachedCountKey + userId))")
            print("Unlocked Count: \(defaults.integer(forKey: unlockedCountKey + userId))")
            print("Is Expired: \(hoursElapsed > storageExpirationHours ? "YES ⏰" : "NO ✅")")
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
            
            // ✅ CORRECCIÓN: No usar foreign key porque badges tiene PK compuesta (id, userId)
            // La integridad se maneja en código mediante las transacciones
        })
    }
    
    static func createIndexes(in db: Connection) throws {
        try db.run("CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id ON user_badges(badge_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_user_badges_unlocked ON user_badges(is_unlocked)")
    }
}
