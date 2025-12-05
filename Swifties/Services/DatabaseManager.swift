//
//  DatabaseManager.swift
//  Swifties
//
//  Centralized singleton to manage all SQLite connections
//

import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()
    
    // Conexión única a la base de datos
    private var db: Connection?
    private let threadManager = ThreadManager.shared
    
    // Acceso público a la conexión (solo lectura)
    var connection: Connection? {
        return db
    }
    
    // MARK: - Inicialización
    
    private init() {
        setupDatabase()
        setupAllTables() // Create all tables at initialization
    }
    
    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            
            // Base de datos unificada
            let dbPath = "\(path)/swifties.sqlite3"
            db = try Connection(dbPath)
            
            #if DEBUG
            print("!!!!! !!!!! Database initialized at: \(dbPath)")
            #endif
            
            // Optimization settings
            try db?.execute("PRAGMA foreign_keys = ON")
            try db?.execute("PRAGMA journal_mode = WAL")
            
        } catch {
            print("❌ Error setting up database: \(error)")
        }
    }
    
    // MARK: - Table Setup
    
    private func setupAllTables() {
        guard let db = db else {
            print("❌ Cannot setup tables: database connection not available")
            return
        }
        
        do {
            // Events table (for events feature)
            try EventsTable.createTable(in: db)
            try EventsTable.createIndexes(in: db)
            
            // Recommendations table (for home recommendations)
            try RecommendationsTable.createTable(in: db)
            try RecommendationsTable.createIndexes(in: db)
            
            // Quiz questions table (for mood quiz)
            try QuizQuestionsTable.createTable(in: db)
            try QuizQuestionsTable.createIndexes(in: db)
            
            #if DEBUG
            print("✅ All database tables initialized successfully")
            print("   - events")
            print("   - recommendations")
            print("   - quiz_questions")
            #endif
        } catch {
            print("❌ Error setting up tables: \(error)")
        }
    }
    
    // MARK: - Thread-Safe Operations
    
    /// Ejecuta operaciones de lectura en background thread
    func executeRead<T>(_ operation: @escaping (Connection) throws -> T, completion: @escaping (Swift.Result<T, Error>) -> Void) {
        threadManager.executeDatabaseOperation { [weak self] in
            guard let self = self, let db = self.db else {
                self?.threadManager.executeOnMain {
                    completion(.failure(DatabaseError.connectionNotAvailable))
                }
                return
            }
            
            do {
                let result = try operation(db)
                self.threadManager.executeOnMain {
                    completion(.success(result))
                }
            } catch {
                self.threadManager.executeOnMain {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Ejecuta operaciones de escritura en background thread
    func executeWrite(_ operation: @escaping (Connection) throws -> Void, completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        threadManager.executeDatabaseOperation { [weak self] in
            guard let self = self, let db = self.db else {
                self?.threadManager.executeOnMain {
                    completion?(.failure(DatabaseError.connectionNotAvailable))
                }
                return
            }
            
            do {
                try operation(db)
                self.threadManager.executeOnMain {
                    completion?(.success(()))
                }
            } catch {
                self.threadManager.executeOnMain {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    /// Ejecuta transacciones de forma segura
    func executeTransaction(_ operation: @escaping (Connection) throws -> Void, completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        threadManager.executeDatabaseOperation { [weak self] in
            guard let self = self, let db = self.db else {
                self?.threadManager.executeOnMain {
                    completion?(.failure(DatabaseError.connectionNotAvailable))
                }
                return
            }
            
            do {
                try db.transaction {
                    try operation(db)
                }
                self.threadManager.executeOnMain {
                    completion?(.success(()))
                }
            } catch {
                self.threadManager.executeOnMain {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Utilidades
    
    /// Verifica si una tabla existe
    func tableExists(_ tableName: String, completion: @escaping (Bool) -> Void) {
        executeRead { db in
            let count = try db.scalar(
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?",
                tableName
            ) as! Int64
            return count > 0
        } completion: { result in
            completion((try? result.get()) ?? false)
        }
    }
    
    /// Obtiene información de la base de datos
    func getDatabaseInfo(completion: @escaping (DatabaseInfo) -> Void) {
        executeRead { db in
            let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table'")
                .map { $0[0] as! String }
            
            let size = try FileManager.default.attributesOfItem(atPath: db.description)[.size] as? UInt64 ?? 0
            
            return DatabaseInfo(
                path: db.description,
                tables: tables,
                sizeInBytes: size
            )
        } completion: { result in
            if case .success(let info) = result {
                completion(info)
            }
        }
    }
}

// MARK: - Supporting Types

enum DatabaseError: Error {
    case connectionNotAvailable
    case tableNotFound
    case invalidData
}

struct DatabaseInfo {
    let path: String
    let tables: [String]
    let sizeInBytes: UInt64
    
    var sizeInMB: Double {
        return Double(sizeInBytes) / 1_024_000
    }
}
