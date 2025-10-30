
import SwiftUI
import FirebaseAuth
import Combine

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
        case memoryCache
        case realmStorage
        case network
    }
    
    private let cacheService = WeeklyChallengeCacheService.shared
    private let storageService = WeeklyChallengeStorageService.shared
    private let networkService = WeeklyChallengeNetworkService.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Load Data (Three-Layer Cache)
    
    func loadChallenge() {
        isLoading = true
        errorMessage = nil
        
        guard let userId = currentUserId else {
            isLoading = false
            errorMessage = "User not authenticated"
            return
        }
        
        print("🚀 Loading challenge for user: \(userId)")
        
        // Layer 1: Try memory cache
        if let cached = cacheService.getCachedChallenge(userId: userId) {
            self.challengeEvent = cached.event
            self.hasAttended = cached.hasAttended
            self.totalChallenges = cached.totalChallenges
            self.last30DaysData = cached.chartData
            self.dataSource = .memoryCache
            self.isLoading = false
            print("✅ Loaded from memory cache")
            
            // Try to refresh in background if connected
            refreshInBackground(userId: userId)
            return
        }
        
        // Layer 2: Try Realm storage
        if let stored = storageService.loadChallenge(userId: userId) {
            self.challengeEvent = stored.event
            self.hasAttended = stored.hasAttended
            self.totalChallenges = stored.totalChallenges
            self.last30DaysData = stored.chartData
            self.dataSource = .realmStorage
            self.isLoading = false
            
            // Cache in memory for next time
            cacheService.cacheChallenge(
                userId: userId,
                event: stored.event,
                hasAttended: stored.hasAttended,
                totalChallenges: stored.totalChallenges,
                chartData: stored.chartData
            )
            
            print("✅ Loaded from Realm storage")
            
            // Try to refresh in background if connected
            refreshInBackground(userId: userId)
            return
        }
        
        // Layer 3: Fetch from network
        if networkMonitor.isConnected {
            fetchFromNetwork(userId: userId)
        } else {
            isLoading = false
            errorMessage = "No internet connection and no cached data available"
            print("❌ No connection and no local data")
        }
    }
    
    private func fetchFromNetwork(userId: String) {
        networkService.fetchChallengeData(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    self.challengeEvent = data.event
                    self.hasAttended = data.hasAttended
                    self.totalChallenges = data.totalChallenges
                    self.last30DaysData = data.chartData
                    self.dataSource = .network
                    
                    // Save to both cache layers
                    self.cacheService.cacheChallenge(
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
                    
                    print("✅ Loaded from network and cached")
                    
                case .failure(let error):
                    self.errorMessage = "Error loading challenge: \(error.localizedDescription)"
                    print("❌ Network error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func refreshInBackground(userId: String) {
        guard networkMonitor.isConnected else { return }
        
        self.isRefreshing = true
        networkService.fetchChallengeData(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                
                if case .success(let data) = result {
                    // Update data silently (sin cambiar la UI visiblemente)
                    self.challengeEvent = data.event
                    self.hasAttended = data.hasAttended
                    self.totalChallenges = data.totalChallenges
                    self.last30DaysData = data.chartData
                    // Do NOT change dataSource - keep the cache indicator
                    
                    // Update caches for next time
                    self.cacheService.cacheChallenge(
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
                    
                    print("✅ Updated in background (dataSource unchanged)")
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
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success():
                    print("✅ Successfully marked as attending")
                    AnalyticsService.shared.logCheckIn(activityId: event.name, category: event.category)
                    
                    // Clear cache and reload to get fresh data
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
        cacheService.clearCache(userId: userId)
        storageService.deleteChallenge(userId: userId)
        loadChallenge()
    }
    
    func clearAllCache() {
        guard let userId = currentUserId else { return }
        cacheService.clearCache(userId: userId)
        storageService.deleteChallenge(userId: userId)
        challengeEvent = nil
        hasAttended = false
        totalChallenges = 0
        last30DaysData = []
        dataSource = .none
    }
    
    func debugCache() {
        guard let userId = currentUserId else { return }
        cacheService.debugCache(userId: userId)
        storageService.debugStorage(userId: userId)
    }
}
