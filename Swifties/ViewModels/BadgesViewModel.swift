//
//  BadgesViewModel.swift (COMPLETE FIX - NOW MATCHES UserInfoViewModel PATTERN)
//  Swifties
//
//  ✅ AHORA SÍ USA loadStaleData() correctamente cuando offline
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
        case localStorageStale  // Para indicar datos antiguos
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
    
    // MARK: - LOAD BADGES (Three-Layer Cache)
    
    func loadBadges() {
        isLoading = true
        errorMessage = nil
        
        guard let userId = currentUserId else {
            isLoading = false
            errorMessage = "User not authenticated"
            return
        }
        
        print("\n🚀 ========================================")
        print("🚀 LOADING BADGES WITH THREE-LAYER CACHE")
        print("🚀 ========================================")
        print("User ID: \(userId)")
        print("Connected: \(networkMonitor.isConnected ? "YES ✅" : "NO ❌")")
        
        // ============================================
        // LAYER 1: Memory Cache
        // ============================================
        if let cached = cacheService.getCachedBadges(userId: userId) {
            self.combineBadgesWithProgress(badges: cached.badges, userBadges: cached.userBadges)
            self.dataSource = .memoryCache
            self.isLoading = false
            print("✅ [LAYER 1] Loaded from memory cache")
            print("========================================\n")
            return
        }
        
        print("⏭️ [LAYER 1] Memory cache empty, trying Layer 2...")
        
        // ============================================
        // LAYER 2: Local Storage (UserDefaults + SQLite)
        // ============================================
        
        // 🔧 CORRECCIÓN: Usar el método apropiado según conexión
        let loadMethod: (String, @escaping ((badges: [Badge], userBadges: [UserBadge])?) -> Void) -> Void
        
        if networkMonitor.isConnected {
            // Online: Respetar expiración (24 horas)
            print("📦 [LAYER 2-ONLINE] Loading with expiration check...")
            loadMethod = storageService.loadBadges
        } else {
            // Offline: Ignorar expiración inicial
            print("📦 [LAYER 2-OFFLINE] Loading ignoring expiration...")
            loadMethod = storageService.loadBadgesIgnoringExpiration
        }
        
        loadMethod(userId) { [weak self] result in
            guard let self = self else { return }
            
            if let data = result {
                // Tenemos datos en storage
                self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                self.dataSource = .localStorage
                self.isLoading = false
                
                // Cache in memory for next time
                self.cacheService.cacheBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                
                print("✅ [LAYER 2] Loaded from local storage")
                
                // Refresh in background if connected
                if self.networkMonitor.isConnected {
                    print("🔄 [LAYER 2] Starting background refresh...")
                    Task {
                        await self.refreshFromNetwork(userId: userId)
                    }
                } else {
                    print("⚠️ [LAYER 2-OFFLINE] Showing cached data, no refresh available")
                }
                
                print("========================================\n")
                return
            }
            
            // No hay datos en Layer 2
            print("⏭️ [LAYER 2] Local storage empty, trying Layer 3...")
            
            // ============================================
            // LAYER 3: Network o Stale Data (ÚLTIMO RECURSO)
            // ============================================
            if self.networkMonitor.isConnected {
                // Tenemos internet: Fetch normal
                print("\n📦 [LAYER 3-NETWORK] Fetching from network...")
                Task {
                    await self.fetchFromNetwork(userId: userId)
                }
            } else {
                // 🆕 SIN INTERNET: Intentar cargar datos antiguos (STALE DATA)
                print("\n📦 [LAYER 3-STALE] No internet - attempting STALE DATA mode...")
                
                self.storageService.loadStaleData(userId: userId) { staleResult in
                    if let staleData = staleResult {
                        // ✅ Encontramos datos antiguos
                        print("✅ [STALE-MODE] Successfully loaded old data")
                        print("   - Badges: \(staleData.badges.count)")
                        print("   - User Badges: \(staleData.userBadges.count)")
                        
                        self.combineBadgesWithProgress(badges: staleData.badges, userBadges: staleData.userBadges)
                        self.dataSource = .localStorageStale
                        self.isLoading = false
                        
                        // ⚠️ Mostrar warning al usuario sobre datos antiguos
                        self.errorMessage = "⚠️ Showing cached data. Connect to internet to refresh."
                        
                        print("⚠️ [STALE-MODE] Displayed warning about outdated data")
                        print("========================================\n")
                    } else {
                        // ❌ No hay datos ni siquiera antiguos
                        print("❌ [STALE-MODE] No stale data available either")
                        self.errorMessage = "No internet connection and no cached data available"
                        self.isLoading = false
                        print("========================================\n")
                    }
                }
            }
        }
    }
    
    // MARK: - FETCH FROM NETWORK
    
    private func fetchFromNetwork(userId: String) async {
        print("🌐 [NETWORK] Fetching from Firestore...")
        
        await MainActor.run {
            self.isLoading = true
        }
        
        // Operación de red en background
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
                    case .failure(let error):
                        print("❌ [NETWORK] Error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        
        // Actualizar UI en main thread
        await MainActor.run {
            self.isLoading = false
            
            if let data = networkData {
                self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                self.dataSource = .network
                self.errorMessage = nil  // Limpiar cualquier warning anterior
                print("✅ [NETWORK] Data loaded successfully")
                print("========================================\n")
                
                // Guardar en ambas capas de cache (background)
                Task.detached(priority: .background) { [weak self] in
                    guard let self = self else { return }
                    
                    self.cacheService.cacheBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                    
                    self.storageService.saveBadges(userId: userId, badges: data.badges, userBadges: data.userBadges) {
                        print("💾 [BACKGROUND] Saved to both caches")
                    }
                }
            } else {
                self.errorMessage = "Failed to load badges from network"
                print("❌ [NETWORK] Fetch failed")
                print("========================================\n")
            }
        }
    }
    
    // MARK: - REFRESH FROM NETWORK (Background)
    
    private func refreshFromNetwork(userId: String) async {
        guard networkMonitor.isConnected else { return }
        
        await MainActor.run {
            self.isRefreshing = true
        }
        
        print("🔄 [REFRESH] Starting background refresh...")
        
        let networkData: (badges: [Badge], userBadges: [UserBadge])? = await withCheckedContinuation { continuation in
            networkService.fetchBadgesData(userId: userId) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: (data.badges, data.userBadges))
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        
        if let data = networkData {
            await MainActor.run {
                // Actualizar UI
                self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                self.dataSource = .network
                self.errorMessage = nil  // Limpiar warning de stale data
                self.isRefreshing = false
                print("✅ [REFRESH] Background refresh completed")
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
    
    // MARK: - COMBINE BADGES
    
    private func combineBadgesWithProgress(badges: [Badge], userBadges: [UserBadge]) {
        self.badgesWithProgress = badges.compactMap { badge in
            if let userBadge = userBadges.first(where: { $0.badgeId == badge.id }) {
                return BadgeWithProgress(badge: badge, userBadge: userBadge)
            }
            return nil
        }.sorted { $0.badge.rarity.rawValue > $1.badge.rarity.rawValue }
    }
    
    // MARK: - CACHE MANAGEMENT
    
    func forceRefresh() {
        guard let userId = currentUserId else { return }
        
        print("🗑️ [FORCE REFRESH] Clearing caches...")
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            self.cacheService.clearCache(userId: userId)
            self.storageService.deleteBadges(userId: userId)
            
            await MainActor.run {
                print("✅ [FORCE REFRESH] Caches cleared, reloading...")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadBadges()
        }
    }
    
    func clearAllCache() {
        guard let userId = currentUserId else { return }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            self.cacheService.clearCache(userId: userId)
            self.storageService.deleteBadges(userId: userId)
        }
        
        badgesWithProgress = []
        dataSource = .none
        errorMessage = nil
    }
    
    func debugCache() {
        guard let userId = currentUserId else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            self.cacheService.debugCache(userId: userId)
            self.storageService.debugStorage(userId: userId)
        }
    }
}
