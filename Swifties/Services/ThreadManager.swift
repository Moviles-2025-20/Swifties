//
//  ThreadManager.swift
//  Swifties
//
//  Thread management singleton using Grand Central Dispatch
//

import Foundation

class ThreadManager {
    static let shared = ThreadManager()
    
    // MARK: - Queue Definitions
    
    /// Cola serial para operaciones de red (Firestore)
    private let networkQueue = DispatchQueue(
        label: "com.swifties.network",
        qos: .userInitiated
    )
    
    /// Cola serial para operaciones de base de datos (SQLite)
    private let databaseQueue = DispatchQueue(
        label: "com.swifties.database",
        qos: .utility
    )
    
    /// Cola concurrente para operaciones de caché en memoria
    private let cacheQueue = DispatchQueue(
        label: "com.swifties.cache",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    /// Cola para procesamiento de notificaciones
    private let notificationQueue = DispatchQueue(
        label: "com.swifties.notifications",
        qos: .utility
    )
    
    /// Cola principal (UI)
    var mainQueue: DispatchQueue {
        return DispatchQueue.main
    }
    
    private init() {
        print("ThreadManager initialized")
    }
    
    // MARK: - Network Operations
    
    /// Ejecuta operaciones de red en background
    func executeNetworkOperation(_ operation: @escaping () -> Void) {
        networkQueue.async {
            operation()
        }
    }
    
    /// Ejecuta operación de red y retorna al main thread
    func executeNetworkOperation<T>(
        operation: @escaping () -> T,
        completion: @escaping (T) -> Void
    ) {
        networkQueue.async {
            let result = operation()
            self.mainQueue.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Database Operations
    
    /// Ejecuta operaciones de base de datos en background
    func executeDatabaseOperation(_ operation: @escaping () -> Void) {
        databaseQueue.async {
            operation()
        }
    }
    
    /// Ejecuta operación de BD con completion en main thread
    func executeDatabaseOperation<T>(
        operation: @escaping () -> T,
        completion: @escaping (T) -> Void
    ) {
        databaseQueue.async {
            let result = operation()
            self.mainQueue.async {
                completion(result)
            }
        }
    }
    
    // MARK: - Cache Operations
    
    /// Lee del caché (operación concurrente)
    func readFromCache<T>(operation: @escaping () -> T, completion: @escaping (T) -> Void) {
        cacheQueue.async {
            let result = operation()
            self.mainQueue.async {
                completion(result)
            }
        }
    }
    
    /// Escribe al caché con barrier (operación exclusiva)
    func writeToCache(operation: @escaping () -> Void, completion: (() -> Void)? = nil) {
        cacheQueue.async(flags: .barrier) {
            operation()
            if let completion = completion {
                self.mainQueue.async {
                    completion()
                }
            }
        }
    }
    
    // MARK: - Notification Processing
    
    /// Procesa notificaciones en background
    func processNotifications(_ operation: @escaping () -> Void) {
        notificationQueue.async {
            operation()
        }
    }
    
    // MARK: - Main Thread Operations
    
    /// Ejecuta en el main thread
    func executeOnMain(_ operation: @escaping () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            mainQueue.async {
                operation()
            }
        }
    }
    
    // MARK: - Group Operations
    /// Ejecuta múltiples operaciones y notifica cuando todas terminan
    func executeGroup(
        operations: [() -> Void],
        completion: @escaping () -> Void
    ) {
        let group = DispatchGroup()
        
        for operation in operations {
            group.enter()
            networkQueue.async {
                operation()
                group.leave()
            }
        }
        
        group.notify(queue: mainQueue) {
            completion()
        }
    }
    
    // MARK: - Utility Methods
    /// Espera específica en background (evitar bloqueos)
    func delay(_ seconds: Double, queue: DispatchQueue? = nil, operation: @escaping () -> Void) {
        let targetQueue = queue ?? networkQueue
        targetQueue.asyncAfter(deadline: .now() + seconds) {
            operation()
        }
    }
}
