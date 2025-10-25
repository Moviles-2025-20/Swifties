import Foundation

class EventStorageService {
    static let shared = EventStorageService()
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "cached_events"
    private let timestampKey = "cached_events_timestamp"
    private let storageExpirationHours = 24.0
    
    private init() {}
    
    func saveEventsToStorage(_ events: [Event]) {
        do {
            // Convertir Events a CodableEvents
            let codableEvents = events.map { $0.toCodable() }
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(codableEvents)
            
            userDefaults.set(data, forKey: storageKey)
            userDefaults.set(Date(), forKey: timestampKey)
            userDefaults.synchronize()
            
            print("💾 \(events.count) eventos guardados en almacenamiento local (\(data.count) bytes)")
        } catch {
            print("❌ Error guardando eventos en storage: \(error.localizedDescription)")
            print("❌ Detalle: \(error)")
        }
    }
    
    func loadEventsFromStorage() -> [Event]? {
        if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            print("⏱️ Antigüedad: \(String(format: "%.1f", hoursElapsed)) horas")
            
            if hoursElapsed > storageExpirationHours {
                clearStorage()
                return nil
            }
        }
        
        guard let data = userDefaults.data(forKey: storageKey) else {
            print("⚠️ No hay datos en almacenamiento local")
            return nil
        }
        
        print("📦 Datos encontrados: \(data.count) bytes")
        
        do {
            let decoder = JSONDecoder()
            let codableEvents = try decoder.decode([CodableEvent].self, from: data)
            let events = codableEvents.map { Event.from(codable: $0) }
            
            print("✅ \(events.count) eventos cargados desde almacenamiento local")
            return events
        } catch {
            print("❌ Error decodificando: \(error.localizedDescription)")
            clearStorage()
            return nil
        }
    }
    
    func clearStorage() {
        userDefaults.removeObject(forKey: storageKey)
        userDefaults.removeObject(forKey: timestampKey)
        userDefaults.synchronize()
        print("🗑️ Almacenamiento local limpiado")
    }
    
    func debugStorage() {
        print("\n=== DEBUG STORAGE ===")
        if let data = userDefaults.data(forKey: storageKey) {
            print("✓ Datos: \(data.count) bytes")
            if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
                print("✓ Fecha: \(timestamp)")
            }
        } else {
            print("✗ Sin datos")
        }
        print("===================\n")
    }
}
