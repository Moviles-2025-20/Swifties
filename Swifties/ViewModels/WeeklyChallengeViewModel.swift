import SwiftUI
import FirebaseAuth
import Combine

@MainActor
class WeeklyChallengeViewModel: ObservableObject {
    @Published var challengeEvent: Event?
    @Published var totalChallenges: Int = 0
    @Published var last30DaysData: [WeeklyChallengeChartData] = []
    @Published var hasAttended: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    @Published var isRefreshing = false
    
    enum DataSource {
        case none
        case memoryCache      // NSCache - 15 min
        case userDefaults     // UserDefaults - 12 hrs
        case realmStorage     // Realm - 24 hrs
        case network          // Firebase - fresh
    }
    
    private let cacheService = WeeklyChallengeCacheService.shared
    private let userDefaultsService = WeeklyChallengeUserDefaultsService.shared  // New Layer 2A cache
    private let storageService = WeeklyChallengeStorageService.shared
    private let networkService = WeeklyChallengeNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Load Data (FOUR-Layer Cache)
    
    func loadChallenge() {
        isLoading = true
        errorMessage = nil
        
        guard let userId = currentUserId else {
            isLoading = false
            errorMessage = "User not authenticated"
            return
        }
        
        print("\n🚀 ========================================")
        print("🚀 LOADING WEEKLY CHALLENGE")
        print("🚀 ========================================")
        print("User ID: \(userId)")
        print("Connected: \(networkMonitor.isConnected ? "YES" : "NO")")
        print("Current Week: \(Date().weekIdentifier())")
        
        // ============================================
        // LAYER 1: NSCache (Memory - 15 min TTL)
        // ============================================
        print("\n📦 [LAYER 1] Checking NSCache (Memory)...")
        if let cached = cacheService.getCachedChallenge(userId: userId) {
            self.challengeEvent = cached.event
            self.hasAttended = cached.hasAttended
            self.totalChallenges = cached.totalChallenges
            self.last30DaysData = cached.chartData
            self.dataSource = .memoryCache
            self.isLoading = false
            print("✅ Loaded from MEMORY CACHE")
            print("   - Event: \(cached.event?.name ?? "nil")")
            print("   - Has Attended: \(cached.hasAttended)")
            
            // Background refresh if connected
            if networkMonitor.isConnected {
                print("🔄 Starting background refresh...")
                refreshInBackground(userId: userId)
            }
            return
        }
        print("❌ NSCache miss")
        
        // ============================================
        // LAYER 2: UserDefaults (Disk - 12 hrs TTL)
        // ============================================
        print("\n📦 [LAYER 2] Checking UserDefaults...")
        if let stored = userDefaultsService.loadChallenge(userId: userId) {
            print("✅ Loaded from USERDEFAULTS")
            
            self.challengeEvent = stored.event
            self.hasAttended = stored.hasAttended
            self.totalChallenges = stored.totalChallenges
            self.last30DaysData = stored.chartData
            self.dataSource = .userDefaults
            self.isLoading = false
            
            print("   - Event: \(stored.event?.name ?? "nil")")
            print("   - Has Attended: \(stored.hasAttended)")
            print("   - Total: \(stored.totalChallenges)")
            print("   - Chart Points: \(stored.chartData.count)")
            
            // Repopulate NSCache
            print("💾 Repopulating NSCache...")
            cacheService.cacheChallenge(
                userId: userId,
                event: stored.event,
                hasAttended: stored.hasAttended,
                totalChallenges: stored.totalChallenges,
                chartData: stored.chartData
            )
            
            // Background refresh if connected
            if networkMonitor.isConnected {
                print("🔄 Starting background refresh...")
                refreshInBackground(userId: userId)
            }
            return
        }
        print("❌ UserDefaults miss")
        
        // ============================================
        // LAYER 3: Realm (Disk - 24 hrs TTL)
        // ============================================
        print("\n📦 [LAYER 3] Checking Realm Storage...")
        if let stored = storageService.loadChallenge(userId: userId) {
            print("✅ Loaded from REALM STORAGE")
            
            self.challengeEvent = stored.event
            self.hasAttended = stored.hasAttended
            self.totalChallenges = stored.totalChallenges
            self.last30DaysData = stored.chartData
            self.dataSource = .realmStorage
            self.isLoading = false
            
            print("   - Event: \(stored.event?.name ?? "nil")")
            print("   - Has Attended: \(stored.hasAttended)")
            print("   - Total: \(stored.totalChallenges)")
            print("   - Chart Points: \(stored.chartData.count)")
            
            // Repopulate UserDefaults and NSCache
            print("💾 Repopulating UserDefaults and NSCache...")
            userDefaultsService.saveChallenge(
                userId: userId,
                event: stored.event,
                hasAttended: stored.hasAttended,
                totalChallenges: stored.totalChallenges,
                chartData: stored.chartData
            )
            cacheService.cacheChallenge(
                userId: userId,
                event: stored.event,
                hasAttended: stored.hasAttended,
                totalChallenges: stored.totalChallenges,
                chartData: stored.chartData
            )
            
            // Background refresh if connected
            if networkMonitor.isConnected {
                print("🔄 Starting background refresh...")
                refreshInBackground(userId: userId)
            }
            return
        }
        print("❌ Realm storage miss")
        
        // ============================================
        // LAYER 4: Network (Firebase - always fresh)
        // ============================================
        print("\n📦 [LAYER 4] Fetching from Network...")
        if networkMonitor.isConnected {
            fetchFromNetwork(userId: userId)
        } else {
            isLoading = false
            errorMessage = "No internet connection and no cached data available"
            print("❌ NO CONNECTION and NO LOCAL DATA")
            print("========================================\n")
        }
    }
    
    // MARK: - Network Fetch
    
    private func fetchFromNetwork(userId: String) {
        print("🌐 Starting network request...")
        
        networkService.fetchChallengeData(userId: userId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    print("✅ Network fetch SUCCESS")
                    print("   - Event: \(data.event?.name ?? "nil")")
                    print("   - Has Attended: \(data.hasAttended)")
                    print("   - Total: \(data.totalChallenges)")
                    
                    self.challengeEvent = data.event
                    self.hasAttended = data.hasAttended
                    self.totalChallenges = data.totalChallenges
                    self.last30DaysData = data.chartData
                    self.dataSource = .network
                    
                    // Save to ALL cache layers
                    print("\n💾 Saving to all cache layers...")
                    
                    print("   [1/3] Saving to NSCache...")
                    self.cacheService.cacheChallenge(
                        userId: userId,
                        event: data.event,
                        hasAttended: data.hasAttended,
                        totalChallenges: data.totalChallenges,
                        chartData: data.chartData
                    )
                    
                    print("   [2/3] Saving to UserDefaults...")
                    self.userDefaultsService.saveChallenge(
                        userId: userId,
                        event: data.event,
                        hasAttended: data.hasAttended,
                        totalChallenges: data.totalChallenges,
                        chartData: data.chartData
                    )
                    
                    print("   [3/3] Saving to Realm Storage...")
                    self.storageService.saveChallenge(
                        userId: userId,
                        event: data.event,
                        hasAttended: data.hasAttended,
                        totalChallenges: data.totalChallenges,
                        chartData: data.chartData
                    )
                    
                    print("✅ All saves completed")
                    print("========================================\n")
                    
                case .failure(let error):
                    self.errorMessage = "Error loading challenge: \(error.localizedDescription)"
                    print("❌ Network fetch FAILED: \(error.localizedDescription)")
                    print("========================================\n")
                }
            }
        }
    }
    
    // MARK: - Background Refresh
    
    private func refreshInBackground(userId: String) {
        guard networkMonitor.isConnected else { return }
        
        self.isRefreshing = true
        print("🔄 Background refresh started...")
        
        networkService.fetchChallengeData(userId: userId) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isRefreshing = false
                
                if case .success(let data) = result {
                    print("✅ Background refresh SUCCESS")
                    
                    // Update data silently
                    self.challengeEvent = data.event
                    self.hasAttended = data.hasAttended
                    self.totalChallenges = data.totalChallenges
                    self.last30DaysData = data.chartData
                    
                    // Update ALL cache layers
                    self.cacheService.cacheChallenge(
                        userId: userId,
                        event: data.event,
                        hasAttended: data.hasAttended,
                        totalChallenges: data.totalChallenges,
                        chartData: data.chartData
                    )
                    
                    self.userDefaultsService.saveChallenge(
                        userId: userId,
                        event: data.event,
                        hasAttended: data.hasAttended,
                        totalChallenges: data.totalChallenges,
                        chartData: data.chartData
                    )
                    
                    self.storageService.saveChallenge(
                        userId: userId,
                        event: data.event,
                        hasAttended: data.hasAttended,
                        totalChallenges: data.totalChallenges,
                        chartData: data.chartData
                    )
                    
                    print("💾 Background caches updated")
                } else {
                    print("⚠️ Background refresh failed")
                }
            }
        }
    }
    
    // MARK: - Mark as Attending
    
    func markAsAttending() {
        guard let userId = currentUserId, let event = challengeEvent else {
            print("❌ No user or event available")
            return
        }
        
        print("🔵 Marking as attending...")
        
        networkService.markAsAttending(userId: userId, event: event) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success():
                    print("✅ Successfully marked as attending")
                    AnalyticsService.shared.logCheckIn(activityId: event.name, category: event.category)
                    BadgeProgressService.shared.updateProgressAfterActivity(
                        userId: userId,
                        activityType: .weeklyChallenge
                    )
                    // Clear all caches and reload
                    self.forceRefresh()
                    
                case .failure(let error):
                    self.errorMessage = "Error saving activity: \(error.localizedDescription)"
                    print("❌ Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    func forceRefresh() {
        guard let userId = currentUserId else { return }
        print("\n🔄 FORCE REFRESH - Clearing all caches")
        cacheService.clearCache(userId: userId)
        userDefaultsService.clearStorage(userId: userId)
        storageService.deleteChallenge(userId: userId)
        loadChallenge()
    }
    
    func clearAllCache() {
        guard let userId = currentUserId else { return }
        print("\n🗑️ CLEAR ALL CACHE")
        cacheService.clearCache(userId: userId)
        userDefaultsService.clearStorage(userId: userId)
        storageService.deleteChallenge(userId: userId)
        challengeEvent = nil
        hasAttended = false
        totalChallenges = 0
        last30DaysData = []
        dataSource = .none
    }
    
    func debugCache() {
        guard let userId = currentUserId else { return }
        print("\n🐛 DEBUG ALL CACHE LAYERS")
        cacheService.debugCache(userId: userId)
        userDefaultsService.debugStorage(userId: userId)
        storageService.debugStorage(userId: userId)
    }
}
