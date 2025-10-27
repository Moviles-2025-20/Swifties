
import Foundation
import Combine

class EventListViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    
    enum DataSource {
        case none
        case memoryCache
        case localStorage
        case network
    }
    
    private let cacheService = EventCacheService.shared
    private let storageService = EventStorageService.shared
    private let networkService = EventNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    init() {}
    
    func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        // Paso 1: Intentar cargar desde caché en memoria
        if let cachedEvents = cacheService.getCachedEvents() {
            self.events = cachedEvents
            self.dataSource = .memoryCache
            self.isLoading = false
            print("📱 Datos cargados desde caché de memoria")
            return
        }
        
        // Paso 2: Intentar cargar desde almacenamiento local
        if let storedEvents = storageService.loadEventsFromStorage() {
            self.events = storedEvents
            self.dataSource = .localStorage
            self.isLoading = false
            
            // Guardar también en caché de memoria para futuras consultas
            cacheService.cacheEvents(storedEvents)
            print("💾 Datos cargados desde almacenamiento local")
            
            // Intentar actualizar en segundo plano si hay conexión
            refreshInBackground()
            return
        }
        
        // Paso 3: Verificar conexión y hacer petición de red
        if networkMonitor.isConnected {
            fetchFromNetwork()
        } else {
            isLoading = false
            errorMessage = "No internet connection and no saved data found"
            print("❌ Sin conexión y sin datos locales")
        }
    }
    
    private func fetchFromNetwork() {
        networkService.fetchEvents { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let events):
                    self.events = events
                    self.dataSource = .network
                    
                    // Guardar en ambas capas de caché
                    self.cacheService.cacheEvents(events)
                    self.storageService.saveEventsToStorage(events)
                    
                    print("✅ \(events.count) eventos cargados desde red y guardados en caché")
                    
                case .failure(let error):
                    self.errorMessage = "Error cargando eventos: \(error.localizedDescription)"
                    print("❌ Error de red: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func refreshInBackground() {
        guard networkMonitor.isConnected else { return }
        
        networkService.fetchEvents { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if case .success(let events) = result {
                    self.cacheService.cacheEvents(events)
                    self.storageService.saveEventsToStorage(events)
                    print("🔄 Datos actualizados en segundo plano")
                }
            }
        }
    }
    
    func forceRefresh() {
        cacheService.clearCache()
        loadEvents()
    }
    
    func clearAllCache() {
        cacheService.clearCache()
        storageService.clearStorage()
        events = []
        dataSource = .none
    }
}
