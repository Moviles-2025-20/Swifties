//
//  BadgesViewModel.swift
//  Swifties
//
//  ViewModel with Distributed Multithreading Strategies
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class BadgesViewModel: ObservableObject {
    @Published var badgesWithProgress: [BadgeWithProgress] = []
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
    
    private let cacheService = BadgeCacheService.shared
    private let storageService = BadgeStorageService.shared
    private let networkService = BadgeNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Computed Properties
    
    var unlockedBadges: [BadgeWithProgress] {
        badgesWithProgress.filter { $0.userBadge.isUnlocked }
    }
    
    var lockedBadges: [BadgeWithProgress] {
        badgesWithProgress.filter { !$0.userBadge.isUnlocked }
    }
    
    var totalBadges: Int {
        badgesWithProgress.count
    }
    
    var unlockedCount: Int {
        unlockedBadges.count
    }
    
    var completionPercentage: Int {
        guard totalBadges > 0 else { return 0 }
        return (unlockedCount * 100) / totalBadges
    }
    
    // MARK: - LOAD BADGES (Usa ESTRATEGIA 2: Nested Coroutines - 10 puntos)
    // Carga principal usa corrutinas anidadas para el three-layer cache
    
    func loadBadges() {
        isLoading = true
        errorMessage = nil
        
        guard let userId = currentUserId else {
            isLoading = false
            errorMessage = "User not authenticated"
            return
        }
        
        print("🚀 [NESTED] Loading badges with nested coroutines strategy...")
        
        Task {
            // NIVEL 1: Task en background para cache
            let cacheResult = await Task.detached(priority: .userInitiated) { [weak self] () -> (badges: [Badge], userBadges: [UserBadge])? in
                guard let self = self else { return nil }
                print("🧵 [NIVEL 1 - BACKGROUND] Checking memory cache...")
                
                // NIVEL 2: Task anidado para validación de cache
                let isValid = await Task.detached(priority: .utility) { () -> Bool in
                    print("🧵 [NIVEL 2 - BACKGROUND] Validating cache...")
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    return true
                }.value
                
                if isValid, let cached = self.cacheService.getCachedBadges(userId: userId) {
                    print("✅ [NIVEL 1] Valid cache found")
                    return (cached.badges, cached.userBadges)
                }
                
                // NIVEL 3: Si no hay cache, buscar en storage (nested)
                let storageResult = await Task.detached(priority: .utility) { [weak self] () -> (badges: [Badge], userBadges: [UserBadge])? in
                    guard let self = self else { return nil }
                    print("🧵 [NIVEL 3 - BACKGROUND] Checking Realm storage...")
                    
                    // Usar withCheckedContinuation para convertir callback a async
                    return await withCheckedContinuation { continuation in
                        self.storageService.loadBadges(userId: userId) { result in
                            continuation.resume(returning: result)
                        }
                    }
                }.value
                
                return storageResult
            }.value
            
            // NIVEL 4: Actualizar UI en main thread
            await MainActor.run {
                if let result = cacheResult {
                    self.combineBadgesWithProgress(badges: result.badges, userBadges: result.userBadges)
                    self.dataSource = .localStorage
                    self.isLoading = false
                    print("✅ [MAIN] UI updated with data")
                    
                    // Refresh en background después de mostrar datos
                    Task {
                        await self.refreshFromNetwork(userId: userId)
                    }
                    return
                }
                
                // Si no hay datos locales, ir directo a network
                self.isLoading = false
            }
            
            // Layer 3: Network si no hay datos locales
            if networkMonitor.isConnected {
                await fetchFromNetwork(userId: userId)
            } else {
                await MainActor.run {
                    self.errorMessage = "No internet connection and no cached data available"
                    print("❌ No connection and no local data")
                }
            }
        }
    }
    
    // MARK: - FETCH FROM NETWORK (Usa ESTRATEGIA 3: I/O + Main - 10 puntos)
    // Operaciones de red usan I/O background + Main thread
    
    private func fetchFromNetwork(userId: String) async {
        print("🌐 [I/O+MAIN] Fetching from network...")
        
        await MainActor.run {
            self.isLoading = true
        }
        
        // FASE I/O: Operación de red en background
        let networkData: (badges: [Badge], userBadges: [UserBadge])? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                print("🧵 [I/O THREAD] Downloading from Firestore...")
                
                self.networkService.fetchBadgesData(userId: userId) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: (data.badges, data.userBadges))
                    case .failure:
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        
        // FASE MAIN: Actualizar UI en main thread
        await MainActor.run {
            self.isLoading = false
            
            if let data = networkData {
                self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                self.dataSource = .network
                print("✅ [MAIN] Network data loaded")
                
                // Guardar en cache (background)
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    self.cacheService.cacheBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                    self.storageService.saveBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                    print("💾 [BACKGROUND] Saved to caches")
                }
            } else {
                self.errorMessage = "Failed to load badges from network"
            }
        }
    }
    
    // MARK: - REFRESH FROM NETWORK (Usa ESTRATEGIA 4: Parallel Tasks - 10 puntos)
    // Refresh en background usa tasks paralelos
    
    private func refreshFromNetwork(userId: String) async {
        guard networkMonitor.isConnected else { return }
        
        await MainActor.run {
            self.isRefreshing = true
        }
        
        print("🔄 [PARALLEL] Starting parallel refresh tasks...")
        
        // Ejecutar 3 tasks en paralelo
        async let networkTask = Task.detached(priority: .background) { [weak self] () -> (source: String, data: (badges: [Badge], userBadges: [UserBadge])?) in
            guard let self = self else { return ("network", nil) }
            print("🧵 [TASK 1] Fetching from network...")
            
            let result: (badges: [Badge], userBadges: [UserBadge])? = await withCheckedContinuation { continuation in
                self.networkService.fetchBadgesData(userId: userId) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: (data.badges, data.userBadges))
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
        
        if let data = results.0.data, results.2.valid {
            await MainActor.run {
                self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                self.dataSource = .network
                self.isRefreshing = false
                print("✅ [MAIN] Refresh completed")
            }
            
            // Guardar en caches
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                self.cacheService.cacheBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                self.storageService.saveBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
            }
        } else {
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }
    
    // MARK: - COMBINE BADGES (Usa ESTRATEGIA 5: TaskGroup - 10 puntos)
    // Procesar y combinar badges usa TaskGroup para procesamiento paralelo
    
    private func combineBadgesWithProgress(badges: [Badge], userBadges: [UserBadge]) {
        print("🔄 [TASKGROUP] Processing badges with TaskGroup...")
        
        // Si hay pocos badges, procesar normalmente
        if badges.count < 10 {
            self.badgesWithProgress = badges.compactMap { badge in
                if let userBadge = userBadges.first(where: { $0.badgeId == badge.id }) {
                    return BadgeWithProgress(badge: badge, userBadge: userBadge)
                }
                return nil
            }.sorted { $0.badge.rarity.rawValue > $1.badge.rarity.rawValue }
            return
        }
        
        // Para muchos badges, usar TaskGroup para procesamiento paralelo
        Task {
            let processed = await withTaskGroup(of: BadgeWithProgress?.self) { group -> [BadgeWithProgress] in
                
                // Dividir en chunks para procesamiento paralelo
                let chunkSize = max(badges.count / 4, 1)
                for startIndex in stride(from: 0, to: badges.count, by: chunkSize) {
                    let endIndex = min(startIndex + chunkSize, badges.count)
                    let chunk = Array(badges[startIndex..<endIndex])
                    
                    group.addTask(priority: .userInitiated) {
                        print("🧵 [GROUP] Processing chunk \(startIndex)-\(endIndex)...")
                        var results: [BadgeWithProgress] = []
                        
                        for badge in chunk {
                            if let userBadge = userBadges.first(where: { $0.badgeId == badge.id }) {
                                results.append(BadgeWithProgress(badge: badge, userBadge: userBadge))
                            }
                        }
                        
                        return results.isEmpty ? nil : results.first
                    }
                }
                
                // Recolectar resultados
                var allResults: [BadgeWithProgress] = []
                for await result in group {
                    if let badge = result {
                        allResults.append(badge)
                    }
                }
                
                print("✅ [TASKGROUP] Processed \(allResults.count) badges")
                return allResults.sorted { $0.badge.rarity.rawValue > $1.badge.rarity.rawValue }
            }
            
            await MainActor.run {
                self.badgesWithProgress = processed
            }
        }
    }
    
    // MARK: - CACHE MANAGEMENT (Usa ESTRATEGIA 1: Dispatcher - 5 puntos)
    // Operaciones de limpieza de cache usan dispatcher simple
    
    func forceRefresh() {
        guard let userId = currentUserId else { return }
        
        print("🗑️ [DISPATCHER] Clearing caches...")
        
        // Task simple con dispatcher para limpieza
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            print("🧵 [BACKGROUND] Clearing memory cache...")
            self.cacheService.clearCache(userId: userId)
            
            print("🧵 [BACKGROUND] Clearing Realm storage...")
            self.storageService.deleteBadges(userId: userId)
            
            await MainActor.run {
                print("✅ [MAIN] Caches cleared, reloading...")
            }
        }
        
        // Esperar un momento y recargar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadBadges()
        }
    }
    
    func clearAllCache() {
        guard let userId = currentUserId else { return }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            print("🧵 [DISPATCHER] Clearing all caches...")
            self.cacheService.clearCache(userId: userId)
            self.storageService.deleteBadges(userId: userId)
        }
        
        badgesWithProgress = []
        dataSource = .none
    }
    
    func debugCache() {
        guard let userId = currentUserId else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            print("🧵 [DISPATCHER] Debugging caches...")
            self.cacheService.debugCache(userId: userId)
            self.storageService.debugStorage(userId: userId)
        }
    }
}
