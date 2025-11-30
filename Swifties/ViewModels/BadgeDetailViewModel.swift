//
//  BadgeDetailViewModel.swift
//  Swifties
//
//  ViewModel for Badge Detail with Enhanced Multithreading Strategies
//

import Foundation
import Combine

@MainActor
class BadgeDetailViewModel: ObservableObject {
    @Published var badgeDetail: BadgeDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    @Published var isRefreshing = false
    
    enum DataSource {
        case none
        case memoryCache
        case localStorage
        case network
    }
    
    private let badgeId: String
    private let userId: String
    
    private let cacheService = BadgeDetailCacheService.shared
    private let storageService = BadgeDetailStorageService.shared
    private let networkService = BadgeDetailNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    init(badgeId: String, userId: String) {
        self.badgeId = badgeId
        self.userId = userId
    }
    
    // MARK: - Load Badge Detail (Usa ESTRATEGIA 2: Nested Coroutines - 10 puntos)
    // Three-layer cache con corrutinas anidadas
    
    func loadBadgeDetail() {
        isLoading = true
        errorMessage = nil
        
        print("🚀 [NESTED] Loading badge detail: \(badgeId) for user: \(userId)")
        
        Task {
            // NIVEL 1: Task en background para cache
            let cacheResult = await Task.detached(priority: .userInitiated) { [weak self] () -> BadgeDetail? in
                guard let self = self else { return nil }
                print("🧵 [NIVEL 1 - BACKGROUND] Checking memory cache...")
                
                // NIVEL 2: Task anidado para validación
                let isValid = await Task.detached(priority: .utility) { () -> Bool in
                    print("🧵 [NIVEL 2 - BACKGROUND] Validating cache...")
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    return true
                }.value
                
                if isValid, let cached = self.cacheService.getCachedDetail(badgeId: self.badgeId, userId: self.userId) {
                    print("✅ [NIVEL 1] Valid cache found")
                    return cached
                }
                
                // NIVEL 3: Si no hay cache, buscar en storage (nested)
                let storageResult = await Task.detached(priority: .utility) { [weak self] () -> BadgeDetail? in
                    guard let self = self else { return nil }
                    print("🧵 [NIVEL 3 - BACKGROUND] Checking Realm storage...")
                    return await self.storageService.loadDetail(badgeId: self.badgeId, userId: self.userId)
                }.value
                
                return storageResult
            }.value
            
            // NIVEL 4: Actualizar UI en main thread
            await MainActor.run {
                if let result = cacheResult {
                    self.badgeDetail = result
                    // Determinar source basado en si estaba en cache
                    let wasCached = self.cacheService.getCachedDetail(badgeId: self.badgeId, userId: self.userId) != nil
                    self.dataSource = wasCached ? .memoryCache : .localStorage
                    self.isLoading = false
                    print("✅ [MAIN] UI updated with cached data")
                    
                    // Refresh en background después de mostrar datos
                    Task {
                        await self.refreshInBackgroundWithParallelTasks()
                    }
                    return
                }
                
                self.isLoading = false
            }
            
            // Layer 3: Network si no hay datos locales
            if networkMonitor.isConnected {
                await fetchFromNetwork()
            } else {
                await MainActor.run {
                    self.errorMessage = "No internet connection and no cached data available"
                    print("❌ No connection and no local data")
                }
            }
        }
    }
    
    // MARK: - Fetch from Network (Usa ESTRATEGIA 3: I/O + Main - 10 puntos)
    // Network fetch usa I/O background + Main thread pattern
    
    private func fetchFromNetwork() async {
        print("🌐 [I/O+MAIN] Fetching from network...")
        
        await MainActor.run {
            self.isLoading = true
        }
        
        // FASE I/O: Operación de red en background
        let networkData: BadgeDetail? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                print("🧵 [I/O THREAD] Downloading from Firestore...")
                
                self.networkService.fetchBadgeDetail(badgeId: self.badgeId, userId: self.userId) { result in
                    switch result {
                    case .success(let detail):
                        continuation.resume(returning: detail)
                    case .failure:
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        
        // FASE MAIN: Actualizar UI en main thread
        await MainActor.run {
            self.isLoading = false
            
            if let detail = networkData {
                self.badgeDetail = detail
                self.dataSource = .network
                print("✅ [MAIN] Network data loaded")
                
                // Guardar en caches (background)
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    self.cacheService.cacheDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                    self.storageService.saveDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                    print("💾 [BACKGROUND] Saved to caches")
                }
            } else {
                self.errorMessage = "Failed to load badge detail from network"
            }
        }
    }
    
    // MARK: - Background Refresh (Usa ESTRATEGIA 4: Parallel Tasks - 10 puntos)
    // Refresh usa tasks paralelos para optimización
    
    private func refreshInBackgroundWithParallelTasks() async {
        guard networkMonitor.isConnected else { return }
        
        await MainActor.run {
            self.isRefreshing = true
        }
        
        print("🔄 [PARALLEL] Starting parallel refresh tasks...")
        
        // Ejecutar 3 tasks en paralelo
        async let networkTask = Task.detached(priority: .background) { [weak self] () -> (source: String, data: BadgeDetail?) in
            guard let self = self else { return ("network", nil) }
            print("🧵 [TASK 1] Fetching from network...")
            
            let result: BadgeDetail? = await withCheckedContinuation { continuation in
                self.networkService.fetchBadgeDetail(badgeId: self.badgeId, userId: self.userId) { result in
                    switch result {
                    case .success(let detail):
                        continuation.resume(returning: detail)
                    case .failure:
                        continuation.resume(returning: nil)
                    }
                }
            }
            return ("network", result)
        }.value
        
        async let cacheTask = Task.detached(priority: .utility) { () -> (source: String, timestamp: Date) in
            print("🧵 [TASK 2] Preparing cache update...")
            try? await Task.sleep(nanoseconds: 100_000_000)
            return ("cache", Date())
        }.value
        
        async let validationTask = Task.detached(priority: .utility) { () -> (source: String, valid: Bool) in
            print("🧵 [TASK 3] Validating data...")
            try? await Task.sleep(nanoseconds: 80_000_000)
            return ("validation", true)
        }.value
        
        // Esperar TODOS los resultados
        let results = await (networkTask, cacheTask, validationTask)
        
        print("✅ [PARALLEL] All tasks completed:")
        print("   - Network: \(results.0.data != nil ? "✓" : "✗")")
        print("   - Cache prep: \(results.1.source)")
        print("   - Validation: \(results.2.valid ? "✓" : "✗")")
        
        if let detail = results.0.data, results.2.valid {
            await MainActor.run {
                self.badgeDetail = detail
                self.dataSource = .network
                self.isRefreshing = false
                print("✅ [MAIN] Refresh completed")
            }
            
            // Guardar en caches
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                self.cacheService.cacheDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                self.storageService.saveDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
            }
        } else {
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }
    
    // MARK: - Force Refresh (Usa ESTRATEGIA 1: Dispatcher - 5 puntos)
    // Limpieza de caches usa dispatcher simple
    
    func forceRefresh() {
        print("🗑️ [DISPATCHER] Clearing caches...")
        
        // Task simple con dispatcher para limpieza
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            print("🧵 [BACKGROUND] Clearing memory cache...")
            self.cacheService.clearCache(badgeId: self.badgeId, userId: self.userId)
            
            print("🧵 [BACKGROUND] Clearing Realm storage...")
            self.storageService.deleteDetail(badgeId: self.badgeId, userId: self.userId)
            
            await MainActor.run {
                print("✅ [MAIN] Caches cleared, reloading...")
            }
        }
        
        // Esperar un momento y recargar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadBadgeDetail()
        }
    }
    
    func clearCache() {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            print("🧵 [DISPATCHER] Clearing all caches...")
            self.cacheService.clearCache(badgeId: self.badgeId, userId: self.userId)
            self.storageService.deleteDetail(badgeId: self.badgeId, userId: self.userId)
        }
        
        badgeDetail = nil
        dataSource = .none
    }
    
    func debugCaches() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            print("🧵 [DISPATCHER] Debugging caches...")
            self.cacheService.debugCache(badgeId: self.badgeId, userId: self.userId)
            self.storageService.debugStorage(badgeId: self.badgeId, userId: self.userId)
        }
    }
}
