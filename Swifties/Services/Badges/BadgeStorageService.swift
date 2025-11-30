//
//  BadgeStorageService.swift
//  Swifties
//
//  Layer 2: Hybrid Storage (UserDefaults + SQLite)
//  ESTRATEGIA HÍBRIDA:
//  - UserDefaults: Metadata, timestamps, quick access data
//  - SQLite: Full badge data, relationships, complex queries
//

import Foundation
import SQLite3

class BadgeStorageService {
    static let shared = BadgeStorageService()
    
    private let storageExpirationHours: Double = 24.0
    
    // UserDefaults keys
    private let lastUpdateKey = "badge_last_update_"
    private let cachedCountKey = "badge_cached_count_"
    private let unlockedCountKey = "badge_unlocked_count_"
    private let userPreferencesKey = "badge_user_preferences_"
    
    // SQLite
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.swifties.sqlite", qos: .utility)
    
    private init() {
        setupSQLite()
    }
    
    deinit {
        closeSQLite()
    }
    
    // MARK: - SQLite Setup
    
    private func setupSQLite() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("badges.sqlite")
        
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            print("❌ Error opening SQLite database")
            return
        }
        
        createTables()
        print("✅ SQLite initialized for Badges")
    }
    
    private func createTables() {
        // Tabla de Badges - UPDATED con isSecret, createdAt, updatedAt
        let createBadgesTable = """
        CREATE TABLE IF NOT EXISTS badges (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            icon TEXT NOT NULL,
            rarity TEXT NOT NULL,
            criteria_type TEXT NOT NULL,
            criteria_value INTEGER NOT NULL,
            is_secret INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """
        
        // Tabla de UserBadges (progreso)
        let createUserBadgesTable = """
        CREATE TABLE IF NOT EXISTS user_badges (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            badge_id TEXT NOT NULL,
            progress INTEGER NOT NULL,
            is_unlocked INTEGER NOT NULL,
            earned_at INTEGER,
            last_updated INTEGER NOT NULL,
            FOREIGN KEY (badge_id) REFERENCES badges(id)
        );
        """
        
        // Índices para optimizar queries
        let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_badges_user_id ON badges(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id ON user_badges(badge_id);
        CREATE INDEX IF NOT EXISTS idx_user_badges_unlocked ON user_badges(is_unlocked);
        """
        
        executeSQL(createBadgesTable)
        executeSQL(createUserBadgesTable)
        executeSQL(createIndexes)
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ SQL executed successfully")
            } else {
                print("❌ Error executing SQL")
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func closeSQLite() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    // MARK: - Save (Hybrid Strategy)
    
    func saveBadges(userId: String, badges: [Badge], userBadges: [UserBadge]) {
        print("💾 [HYBRID] Starting hybrid save for user: \(userId)")
        
        // PASO 1: Guardar metadata en UserDefaults (rápido, main thread)
        saveMetadataToUserDefaults(userId: userId, badges: badges, userBadges: userBadges)
        
        // PASO 2: Guardar datos completos en SQLite (background)
        dbQueue.async { [weak self] in
            self?.saveBadgesToSQLite(userId: userId, badges: badges)
            self?.saveUserBadgesToSQLite(userId: userId, userBadges: userBadges)
            print("✅ [SQLITE] Saved \(badges.count) badges to SQLite")
        }
    }
    
    private func saveMetadataToUserDefaults(userId: String, badges: [Badge], userBadges: [UserBadge]) {
        let defaults = UserDefaults.standard
        
        // Timestamp de última actualización
        defaults.set(Date().timeIntervalSince1970, forKey: lastUpdateKey + userId)
        
        // Contadores rápidos
        defaults.set(badges.count, forKey: cachedCountKey + userId)
        let unlockedCount = userBadges.filter { $0.isUnlocked }.count
        defaults.set(unlockedCount, forKey: unlockedCountKey + userId)
        
        // Guardar IDs de badges desbloqueados para acceso rápido
        let unlockedIds = userBadges.filter { $0.isUnlocked }.map { $0.badgeId }
        defaults.set(unlockedIds, forKey: "unlocked_badge_ids_\(userId)")
        
        defaults.synchronize()
        print("✅ [USERDEFAULTS] Saved metadata for \(badges.count) badges")
    }
    
    private func saveBadgesToSQLite(userId: String, badges: [Badge]) {
        // Primero limpiar badges antiguos del usuario
        let deleteSQL = "DELETE FROM badges WHERE user_id = ?;"
        var deleteStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStmt, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_step(deleteStmt)
        }
        sqlite3_finalize(deleteStmt)
        
        // Insertar nuevos badges - UPDATED con todos los campos
        let insertSQL = """
        INSERT OR REPLACE INTO badges (id, user_id, name, description, icon, rarity, criteria_type, criteria_value, is_secret, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var insertStmt: OpaquePointer?
        
        for badge in badges {
            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStmt, 1, (badge.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 2, (userId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 3, (badge.name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 4, (badge.description as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 5, (badge.icon as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 6, (badge.rarity.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 7, (badge.criteriaType.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_int(insertStmt, 8, Int32(badge.criteriaValue))
                sqlite3_bind_int(insertStmt, 9, badge.isSecret ? 1 : 0)
                sqlite3_bind_text(insertStmt, 10, (badge.createdAt as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 11, (badge.updatedAt as NSString).utf8String, -1, nil)
                
                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    print("❌ Error inserting badge: \(badge.id)")
                }
            }
            sqlite3_finalize(insertStmt)
        }
    }
    
    private func saveUserBadgesToSQLite(userId: String, userBadges: [UserBadge]) {
        // Limpiar progreso antiguo
        let deleteSQL = "DELETE FROM user_badges WHERE user_id = ?;"
        var deleteStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStmt, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_step(deleteStmt)
        }
        sqlite3_finalize(deleteStmt)
        
        // Insertar progreso
        let insertSQL = """
        INSERT OR REPLACE INTO user_badges (id, user_id, badge_id, progress, is_unlocked, earned_at, last_updated)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var insertStmt: OpaquePointer?
        
        for userBadge in userBadges {
            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStmt, 1, (userBadge.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 2, (userId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStmt, 3, (userBadge.badgeId as NSString).utf8String, -1, nil)
                sqlite3_bind_int(insertStmt, 4, Int32(userBadge.progress))
                sqlite3_bind_int(insertStmt, 5, userBadge.isUnlocked ? 1 : 0)
                
                if let earnedAt = userBadge.earnedAt {
                    sqlite3_bind_int64(insertStmt, 6, Int64(earnedAt.timeIntervalSince1970))
                } else {
                    sqlite3_bind_null(insertStmt, 6)
                }
                
                sqlite3_bind_int64(insertStmt, 7, Int64(Date().timeIntervalSince1970))
                
                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    print("❌ Error inserting user badge: \(userBadge.badgeId)")
                }
            }
            sqlite3_finalize(insertStmt)
        }
    }
    
    // MARK: - Load (Hybrid Strategy)
    
    func loadBadges(userId: String) -> (badges: [Badge], userBadges: [UserBadge])? {
        print("📦 [HYBRID] Loading badges for user: \(userId)")
        
        // PASO 1: Validación rápida con UserDefaults
        guard isDataValid(userId: userId) else {
            print("⏰ UserDefaults indicates expired data")
            return nil
        }
        
        // PASO 2: Cargar datos completos de SQLite
        return loadFromSQLite(userId: userId)
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
        
        // Verificar que hay datos guardados
        let cachedCount = defaults.integer(forKey: cachedCountKey + userId)
        if cachedCount == 0 {
            print("❌ No cached count in UserDefaults")
            return false
        }
        
        print("✅ UserDefaults validation passed (\(cachedCount) badges)")
        return true
    }
    
    private func loadFromSQLite(userId: String) -> (badges: [Badge], userBadges: [UserBadge])? {
        var badges: [Badge] = []
        var userBadges: [UserBadge] = []
        
        // Cargar badges - UPDATED para incluir todos los campos
        let badgeSQL = "SELECT * FROM badges WHERE user_id = ?;"
        var badgeStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, badgeSQL, -1, &badgeStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(badgeStmt, 1, (userId as NSString).utf8String, -1, nil)
            
            while sqlite3_step(badgeStmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(badgeStmt, 0))
                let name = String(cString: sqlite3_column_text(badgeStmt, 2))
                let description = String(cString: sqlite3_column_text(badgeStmt, 3))
                let icon = String(cString: sqlite3_column_text(badgeStmt, 4))
                let rarityStr = String(cString: sqlite3_column_text(badgeStmt, 5))
                let criteriaTypeStr = String(cString: sqlite3_column_text(badgeStmt, 6))
                let criteriaValue = Int(sqlite3_column_int(badgeStmt, 7))
                let isSecret = sqlite3_column_int(badgeStmt, 8) == 1
                let createdAt = String(cString: sqlite3_column_text(badgeStmt, 9))
                let updatedAt = String(cString: sqlite3_column_text(badgeStmt, 10))
                
                if let rarity = BadgeRarity(rawValue: rarityStr),
                   let criteriaType = CriteriaType(rawValue: criteriaTypeStr) {
                    let badge = Badge(
                        id: id,
                        name: name,
                        description: description,
                        icon: icon,
                        rarity: rarity,
                        criteriaType: criteriaType,
                        criteriaValue: criteriaValue,
                        isSecret: isSecret,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                    badges.append(badge)
                }
            }
        }
        sqlite3_finalize(badgeStmt)
        
        // Cargar user badges
        let userBadgeSQL = "SELECT * FROM user_badges WHERE user_id = ?;"
        var userBadgeStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, userBadgeSQL, -1, &userBadgeStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(userBadgeStmt, 1, (userId as NSString).utf8String, -1, nil)
            
            while sqlite3_step(userBadgeStmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(userBadgeStmt, 0))
                let userId = String(cString: sqlite3_column_text(userBadgeStmt, 1))
                let badgeId = String(cString: sqlite3_column_text(userBadgeStmt, 2))
                let progress = Int(sqlite3_column_int(userBadgeStmt, 3))
                let isUnlocked = sqlite3_column_int(userBadgeStmt, 4) == 1
                
                var earnedAt: Date?
                if sqlite3_column_type(userBadgeStmt, 5) != SQLITE_NULL {
                    let earnedAtTimestamp = sqlite3_column_int64(userBadgeStmt, 5)
                    earnedAt = Date(timeIntervalSince1970: TimeInterval(earnedAtTimestamp))
                }
                
                let userBadge = UserBadge(
                    id: id,
                    userId: userId,
                    badgeId: badgeId,
                    progress: progress,
                    isUnlocked: isUnlocked,
                    earnedAt: earnedAt
                )
                userBadges.append(userBadge)
            }
        }
        sqlite3_finalize(userBadgeStmt)
        
        guard !badges.isEmpty else {
            print("❌ No badges found in SQLite")
            return nil
        }
        
        print("✅ Loaded \(badges.count) badges and \(userBadges.count) user badges from SQLite")
        return (badges: badges, userBadges: userBadges)
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
    
    func getUnlockedBadgesOnly(userId: String) -> [Badge]? {
        var badges: [Badge] = []
        
        let sql = """
        SELECT b.* FROM badges b
        INNER JOIN user_badges ub ON b.id = ub.badge_id
        WHERE b.user_id = ? AND ub.is_unlocked = 1;
        """
        
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let description = String(cString: sqlite3_column_text(stmt, 3))
                let icon = String(cString: sqlite3_column_text(stmt, 4))
                let rarityStr = String(cString: sqlite3_column_text(stmt, 5))
                let criteriaTypeStr = String(cString: sqlite3_column_text(stmt, 6))
                let criteriaValue = Int(sqlite3_column_int(stmt, 7))
                let isSecret = sqlite3_column_int(stmt, 8) == 1
                let createdAt = String(cString: sqlite3_column_text(stmt, 9))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 10))
                
                if let rarity = BadgeRarity(rawValue: rarityStr),
                   let criteriaType = CriteriaType(rawValue: criteriaTypeStr) {
                    let badge = Badge(
                        id: id,
                        name: name,
                        description: description,
                        icon: icon,
                        rarity: rarity,
                        criteriaType: criteriaType,
                        criteriaValue: criteriaValue,
                        isSecret: isSecret,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                    badges.append(badge)
                }
            }
        }
        sqlite3_finalize(stmt)
        
        return badges.isEmpty ? nil : badges
    }
    
    func getBadgesByRarity(userId: String, rarity: BadgeRarity) -> [Badge]? {
        var badges: [Badge] = []
        
        let sql = "SELECT * FROM badges WHERE user_id = ? AND rarity = ?;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (rarity.rawValue as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let description = String(cString: sqlite3_column_text(stmt, 3))
                let icon = String(cString: sqlite3_column_text(stmt, 4))
                let criteriaTypeStr = String(cString: sqlite3_column_text(stmt, 6))
                let criteriaValue = Int(sqlite3_column_int(stmt, 7))
                let isSecret = sqlite3_column_int(stmt, 8) == 1
                let createdAt = String(cString: sqlite3_column_text(stmt, 9))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 10))
                
                if let criteriaType = CriteriaType(rawValue: criteriaTypeStr) {
                    let badge = Badge(
                        id: id,
                        name: name,
                        description: description,
                        icon: icon,
                        rarity: rarity,
                        criteriaType: criteriaType,
                        criteriaValue: criteriaValue,
                        isSecret: isSecret,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                    badges.append(badge)
                }
            }
        }
        sqlite3_finalize(stmt)
        
        return badges.isEmpty ? nil : badges
    }
    
    // MARK: - Delete
    
    func deleteBadges(userId: String) {
        print("🗑️ [HYBRID] Deleting badges for user: \(userId)")
        
        // Limpiar UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: lastUpdateKey + userId)
        defaults.removeObject(forKey: cachedCountKey + userId)
        defaults.removeObject(forKey: unlockedCountKey + userId)
        defaults.removeObject(forKey: "unlocked_badge_ids_\(userId)")
        defaults.synchronize()
        
        // Limpiar SQLite
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            var stmt: OpaquePointer?
            
            // Delete badges
            let deleteBadgesSQL = "DELETE FROM badges WHERE user_id = ?;"
            if sqlite3_prepare_v2(self.db, deleteBadgesSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            
            // Delete user badges
            let deleteUserBadgesSQL = "DELETE FROM user_badges WHERE user_id = ?;"
            if sqlite3_prepare_v2(self.db, deleteUserBadgesSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            
            print("✅ [SQLITE] Deleted all badges for user")
        }
    }
    
    func clearAllStorage() {
        print("🗑️ [HYBRID] Clearing all storage")
        
        // Limpiar UserDefaults (buscar todas las keys relacionadas)
        let defaults = UserDefaults.standard
        let dict = defaults.dictionaryRepresentation()
        for key in dict.keys {
            if key.contains("badge_") {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
        
        // Limpiar SQLite
        dbQueue.async { [weak self] in
            self?.executeSQL("DELETE FROM badges;")
            self?.executeSQL("DELETE FROM user_badges;")
            print("✅ [SQLITE] All data cleared")
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
        
        // Debug SQLite
        var totalBadges = 0
        var totalUserBadges = 0
        
        let badgeCountSQL = "SELECT COUNT(*) FROM badges WHERE user_id = ?;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, badgeCountSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalBadges = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        let userBadgeCountSQL = "SELECT COUNT(*) FROM user_badges WHERE user_id = ?;"
        if sqlite3_prepare_v2(db, userBadgeCountSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalUserBadges = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        print("\n[SQLITE]")
        print("Total Badges: \(totalBadges)")
        print("Total User Badges: \(totalUserBadges)")
        
        print("============================\n")
    }
}
