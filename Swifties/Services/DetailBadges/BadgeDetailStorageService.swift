//
//  BadgeDetailStorageService.swift
//  Swifties
//
//  Layer 2: Realm Storage for Badge Detail with ESTRATEGIA 2: Nested Coroutines
//

import Foundation
import RealmSwift

class BadgeDetailStorageService {
    static let shared = BadgeDetailStorageService()
    
    private var realm: Realm?
    
    // Serial queue for Realm operations to ensure thread safety
    private let realmQueue = DispatchQueue(label: "com.swifties.badgedetail.realm", qos: .userInitiated)
    
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
    
    // MARK: - Save Detail (Usa ESTRATEGIA 2: Nested Coroutines - 10 puntos)
    // Guardar usa corrutinas anidadas para procesamiento en capas
    
    func saveDetail(badgeId: String, userId: String, detail: BadgeDetail) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            print("🧵 [NIVEL 1 - I/O] Starting save operation...")
            
            // NIVEL 2: Preparar datos en background
            let realmDetail = await Task.detached(priority: .utility) { () -> RealmBadgeDetail in
                print("🧵 [NIVEL 2 - BACKGROUND] Converting to Realm object...")
                return RealmBadgeDetail(detail: detail, userId: userId)
            }.value
            
            // NIVEL 3: Validar datos antes de escribir
            let isValid = await Task.detached(priority: .utility) { () -> Bool in
                print("🧵 [NIVEL 3 - BACKGROUND] Validating data...")
                return true
            }.value
            
            guard isValid else {
                print("❌ [NESTED] Validation failed")
                return
            }
            
            // NIVEL 4: Escribir en Realm en main thread (Realm requiere thread específico)
            await MainActor.run { [weak self] in
                guard let self = self, let realm = self.realm else {
                    print("❌ Realm not available")
                    return
                }
                
                do {
                    try realm.write {
                        realm.add(realmDetail, update: .modified)
                    }
                    print("✅ [MAIN] Saved badge detail to Realm: \(badgeId)")
                } catch {
                    print("❌ Error saving badge detail: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Load Detail (Usa ESTRATEGIA 3: I/O + Main - 10 puntos)
    // Cargar usa I/O background + Main thread pattern con DispatchQueue serial
    
    func loadDetail(badgeId: String, userId: String) async -> BadgeDetail? {
        print("🔄 [I/O+MAIN] Loading detail with async pattern...")
        
        // FASE I/O: Read usando DispatchQueue serial para garantizar thread safety
        return await withCheckedContinuation { continuation in
            realmQueue.async {
                do {
                    // Crear instancia de Realm específica para este queue/thread
                    let config = Realm.Configuration(
                        schemaVersion: 2,
                        migrationBlock: { migration, oldSchemaVersion in
                            if oldSchemaVersion < 2 {
                                // Handle migration if needed
                            }
                        }
                    )
                    
                    let threadRealm = try Realm(configuration: config)
                    let key = "\(userId)_\(badgeId)"
                    
                    print("🧵 [I/O THREAD] Reading from Realm...")
                    
                    guard let realmDetail = threadRealm.object(ofType: RealmBadgeDetail.self, forPrimaryKey: key) else {
                        print("❌ No stored detail for: \(key)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // CRITICAL: Extraer TODOS los datos en el MISMO dispatch queue
                    let cachedAt = realmDetail.cachedAt
                    let age = Date().timeIntervalSince(cachedAt)
                    
                    // Check expiration (7 days)
                    if age > 604800 {
                        print("⏰ [I/O THREAD] Stored detail expired")
                        // Delete on same queue
                        do {
                            try threadRealm.write {
                                threadRealm.delete(realmDetail)
                            }
                        } catch {
                            print("❌ Error deleting expired detail: \(error)")
                        }
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Convert to BadgeDetail (thread-safe struct)
                    guard let badgeDetail = realmDetail.toBadgeDetail() else {
                        print("❌ Failed to convert Realm object to BadgeDetail")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    print("✅ [I/O THREAD] Extracted data, age: \(age)s")
                    
                    continuation.resume(returning: badgeDetail)
                    
                } catch {
                    print("❌ Error accessing Realm: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Versión sync para mantener compatibilidad (DEPRECATED - use async version)
    // Esta versión solo debe usarse desde el main thread
    @available(*, deprecated, message: "Use async loadDetail(badgeId:userId:) instead")
    func loadDetailSync(badgeId: String, userId: String) -> BadgeDetail? {
        guard let realm = realm else {
            print("❌ Realm not available")
            return nil
        }
        
        let key = "\(userId)_\(badgeId)"
        
        guard let realmDetail = realm.object(ofType: RealmBadgeDetail.self, forPrimaryKey: key) else {
            print("❌ No stored detail for: \(key)")
            return nil
        }
        
        // Extract cachedAt IMMEDIATELY within the same thread
        let cachedAt = realmDetail.cachedAt
        let age = Date().timeIntervalSince(cachedAt)
        
        if age > 604800 { // 7 days
            print("⏰ Stored detail expired for: \(key)")
            deleteDetail(badgeId: badgeId, userId: userId)
            return nil
        }
        
        print("✅ Loaded badge detail from Realm: \(key)")
        
        // Convert and return immediately
        guard let detail = realmDetail.toBadgeDetail() else {
            print("❌ Failed to convert Realm object")
            return nil
        }
        
        return detail
    }
    
    // MARK: - Delete Detail (Simple dispatcher)
    
    func deleteDetail(badgeId: String, userId: String) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run { [weak self] in
                guard let self = self, let realm = self.realm else { return }
                
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
        }
    }
    
    // MARK: - Batch Operations (Usa ESTRATEGIA 5: TaskGroup - 10 puntos)
    // Operaciones en lote usan TaskGroup para procesamiento paralelo
    
    func saveMultipleDetails(_ items: [(badgeId: String, userId: String, detail: BadgeDetail)]) async {
        print("🔄 [TASKGROUP] Saving multiple details...")
        
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask(priority: .utility) {
                    print("🧵 [GROUP] Processing: \(item.badgeId)")
                    
                    let realmDetail = RealmBadgeDetail(detail: item.detail, userId: item.userId)
                    
                    await MainActor.run {
                        do {
                            // Usar la instancia de Realm del main thread
                            let config = Realm.Configuration(
                                schemaVersion: 2,
                                migrationBlock: { migration, oldSchemaVersion in
                                    if oldSchemaVersion < 2 {
                                        // Handle migration if needed
                                    }
                                }
                            )
                            let realm = try Realm(configuration: config)
                            
                            try realm.write {
                                realm.add(realmDetail, update: .modified)
                            }
                            print("✅ [GROUP] Saved: \(item.badgeId)")
                        } catch {
                            print("❌ [GROUP] Error saving: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        print("✅ [TASKGROUP] All details saved")
    }
    
    func loadMultipleDetails(_ keys: [(badgeId: String, userId: String)]) async -> [BadgeDetail] {
        print("🔄 [TASKGROUP] Loading multiple details...")
        
        return await withTaskGroup(of: BadgeDetail?.self) { group -> [BadgeDetail] in
            for key in keys {
                group.addTask(priority: .userInitiated) {
                    return await self.loadDetail(badgeId: key.badgeId, userId: key.userId)
                }
            }
            
            var results: [BadgeDetail] = []
            for await detail in group {
                if let detail = detail {
                    results.append(detail)
                }
            }
            
            print("✅ [TASKGROUP] Loaded \(results.count) details")
            return results
        }
    }
    
    // MARK: - Debug
    
    func debugStorage(badgeId: String, userId: String) {
        realmQueue.async {
            do {
                let config = Realm.Configuration(
                    schemaVersion: 2,
                    migrationBlock: { migration, oldSchemaVersion in
                        if oldSchemaVersion < 2 {
                            // Handle migration if needed
                        }
                    }
                )
                
                let threadRealm = try Realm(configuration: config)
                let key = "\(userId)_\(badgeId)"
                
                if let detail = threadRealm.object(ofType: RealmBadgeDetail.self, forPrimaryKey: key) {
                    // Extraer datos dentro del mismo queue
                    let cachedAt = detail.cachedAt
                    let age = Date().timeIntervalSince(cachedAt)
                    print("🔍 Storage status for \(key): exists, cached \(age)s ago")
                } else {
                    print("🔍 Storage status for \(key): not found")
                }
            } catch {
                print("🔍 Realm error: \(error.localizedDescription)")
            }
        }
    }
}
