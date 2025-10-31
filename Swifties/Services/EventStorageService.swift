//
//  EventStorageService.swift
//  Swifties
//
//  Modified with multithreading support
//

import Foundation

class EventStorageService {
    static let shared = EventStorageService()
    
    private let databaseManager = EventDatabaseManager.shared
    private let threadManager = ThreadManager.shared
    
    private init() {}
    
    // MARK: - Threaded Storage Operations
    
    /// Guarda eventos en almacenamiento local (SQLite) en background
    func saveEventsToStorage(_ events: [Event], completion: ((Bool) -> Void)? = nil) {
        databaseManager.saveEvents(events) { success in
            completion?(success)
        }
    }
    
    /// Carga eventos desde almacenamiento local en background
    func loadEventsFromStorage(completion: @escaping ([Event]?) -> Void) {
        databaseManager.loadEvents { events in
            completion(events)
        }
    }
    
    /// Versión síncrona (deprecada, usar la versión async)
    @available(*, deprecated, message: "Use loadEventsFromStorage(completion:) instead")
    func loadEventsFromStorage() -> [Event]? {
        var result: [Event]?
        let semaphore = DispatchSemaphore(value: 0)
        
        databaseManager.loadEvents { events in
            result = events
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Limpia el almacenamiento local
    func clearStorage(completion: ((Bool) -> Void)? = nil) {
        databaseManager.deleteAllEvents { success in
            completion?(success)
        }
    }
    
    /// Obtiene el número de eventos almacenados
    func getStoredEventCount(completion: @escaping (Int) -> Void) {
        databaseManager.getEventCount { count in
            completion(count)
        }
    }
    
    /// Obtiene la fecha de última actualización
    func getLastUpdateTimestamp(completion: @escaping (Date?) -> Void) {
        databaseManager.getLastUpdateTimestamp { date in
            completion(date)
        }
    }
    
    // MARK: - Debug
    
    func debugStorage() {
        databaseManager.debugDatabase()
        
        getStoredEventCount { count in
            print("📊 Total events in storage: \(count)")
        }
        
        getLastUpdateTimestamp { date in
            if let date = date {
                print("🕐 Last update: \(date)")
            } else {
                print("⚠️ No update timestamp found")
            }
        }
    }
}
