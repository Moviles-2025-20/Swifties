import Foundation
import Combine

class EventListViewModel: ObservableObject {    
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
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
    private let threadManager = ThreadManager.shared
    
    init() {}
    
    func loadEvents() {
        // Actualizar UI en main thread
        threadManager.executeOnMain { [weak self] in
            self?.isLoading = true
            self?.errorMessage = nil
        }
        
        // Paso 1: Intentar cargar desde caché en memoria (operación rápida)
        threadManager.readFromCache { [weak self] in
            return self?.cacheService.getCachedEvents()
        } completion: { [weak self] cachedEvents in
            guard let self = self else { return }
            
            if let cachedEvents = cachedEvents {
                self.events = cachedEvents
                self.dataSource = .memoryCache
                self.isLoading = false
                print("Datos cargados desde caché de memoria")
                
                // Intentar actualizar en segundo plano si hay conexión
                self.refreshInBackground()
                return
            }
            
            // Paso 2: Intentar cargar desde almacenamiento local (background)
            self.loadFromLocalStorage()
        }
    }
    
    private func loadFromLocalStorage() {
        storageService.loadEventsFromStorage { [weak self] storedEvents in
            guard let self = self else { return }
            
            if let storedEvents = storedEvents {
                // Actualizar UI en main thread
                self.threadManager.executeOnMain {
                    self.events = storedEvents
                    self.dataSource = .localStorage
                    self.isLoading = false
                }
                
                // Guardar en caché de memoria para futuras consultas
                self.threadManager.writeToCache {
                    self.cacheService.cacheEvents(storedEvents)
                }
                
                print("Datos cargados desde almacenamiento local")
                
                // Intentar actualizar en segundo plano si hay conexión
                self.refreshInBackground()
                return
            }
            
            // Paso 3: Verificar conexión y hacer petición de red
            self.threadManager.executeOnMain {
                if self.networkMonitor.isConnected {
                    self.fetchFromNetwork()
                } else {
                    self.isLoading = false
                    self.errorMessage = "No internet connection and no saved data found"
                    print("Sin conexión y sin datos locales")
                }
            }
        }
    }
    
    private func fetchFromNetwork() {
        networkService.fetchEvents { [weak self] result in
            guard let self = self else { return }
            
            // Ya estamos en main thread gracias a ThreadManager
            self.isLoading = false
            self.isRefreshing = false
            
            switch result {
            case .success(let events):
                self.events = events
                self.dataSource = .network
                
                // Guardar en caché de memoria (background con barrier)
                self.threadManager.writeToCache {
                    self.cacheService.cacheEvents(events)
                }
                
                // Guardar en almacenamiento local (background)
                self.storageService.saveEventsToStorage(events) { success in
                    if success {
                        print("\(events.count) eventos guardados en almacenamiento local")
                    }
                }
                
                print("\(events.count) eventos cargados desde red")
                
            case .failure(let error):
                self.errorMessage = "Error cargando eventos: \(error.localizedDescription)"
                print("Error de red: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshInBackground() {
        guard networkMonitor.isConnected else { return }
        
        // Set refreshing flag
        threadManager.executeOnMain { [weak self] in
            self?.isRefreshing = true
        }
        
        print("Actualizando datos en segundo plano...")
        
        networkService.fetchEvents { [weak self] result in
            guard let self = self else { return }
            
            self.threadManager.executeOnMain {
                self.isRefreshing = false
            }
            
            if case .success(let events) = result {
                // Update UI if data changed
                self.threadManager.executeOnMain {
                    self.events = events
                    self.dataSource = .network
                }
                
                // Guardar en ambas capas de caché sin bloquear UI
                self.threadManager.writeToCache {
                    self.cacheService.cacheEvents(events)
                }
                
                self.storageService.saveEventsToStorage(events) { _ in
                    print("Datos actualizados en segundo plano")
                }
            }
        }
    }
    
    func forceRefresh() {
        // Limpiar caché en background
        threadManager.writeToCache { [weak self] in
            self?.cacheService.clearCache()
        } completion: { [weak self] in
            self?.loadEvents()
        }
    }
    
    func clearAllCache() {
        threadManager.executeOnMain { [weak self] in
            self?.isLoading = true
        }
        
        // Limpiar caché de memoria
        threadManager.writeToCache { [weak self] in
            self?.cacheService.clearCache()
        }
        
        // Limpiar almacenamiento local
        storageService.clearStorage { [weak self] success in
            guard let self = self else { return }
            
            self.threadManager.executeOnMain {
                self.events = []
                self.dataSource = .none
                self.isLoading = false
                print(success ? "Caché limpiado completamente" : "Error limpiando caché")
            }
        }
    }
}
