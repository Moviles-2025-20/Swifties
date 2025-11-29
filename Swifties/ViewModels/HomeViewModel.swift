//
//  HomeViewModel.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 4/10/25.
//

import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recommendations: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    @Published var isRefreshing = false
    
    enum DataSource: CustomStringConvertible {
        case none
        case memoryCache
        case localStorage
        case network
        
        var description: String {
            switch self {
            case .none: return "none"
            case .memoryCache: return "memoryCache"
            case .localStorage: return "localStorage"
            case .network: return "network"
            }
        }
    }
    
    private let cacheService = RecommendationCacheService.shared
    private let storageService = RecommendationStorageService.shared
    private let networkService = RecommendationNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    // Refresh throttling
    private var lastRefreshDate: Date?
    private let minRefreshInterval: TimeInterval = 30 // seconds
    private var backgroundRefreshTask: Task<Void, Never>?
    
    init() {}
    
    // MARK: - Load Recommendations (Three-Layer Cache)
    
    func getRecommendations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "No authenticated user"
            return
        }
        
        // Layer 1: Try memory cache
        if let cached = cacheService.getCachedRecommendations(), !cached.isEmpty {
            publishIfChanged(events: cached, source: .memoryCache)
            triggerBackgroundRefreshIfNeeded(userId: userId)
            #if DEBUG
            print("✅ Recommendations loaded from memory cache (\(cached.count) items)")
            #endif
            return
        }
        
        // Layer 2: Try local storage (SQLite)
        if let stored = storageService.loadRecommendationsFromStorage(userId: userId), !stored.isEmpty {
            publishIfChanged(events: stored, source: .localStorage)
            cacheService.cacheRecommendations(stored)
            triggerBackgroundRefreshIfNeeded(userId: userId)
            #if DEBUG
            print("✅ Recommendations loaded from local storage (\(stored.count) items)")
            #endif
            return
        }
        
        // Layer 3: Fetch from network
        if networkMonitor.isConnected {
            await fetchFromNetwork(userId: userId)
        } else {
            errorMessage = "No internet connection and no saved recommendations available"
            dataSource = .none
            #if DEBUG
            print("❌ No connection and no local recommendations")
            #endif
        }
    }
    
    // MARK: - Network
    
    private func fetchRecommendationsAsync(userId: String) async throws -> [Event] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Event], Error>) in
            networkService.fetchRecommendations(userId: userId) { result in
                switch result {
                case .success(let events):
                    continuation.resume(returning: events)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func fetchFromNetwork(userId: String) async {
        do {
            let events = try await fetchRecommendationsAsync(userId: userId)
            
            if events.isEmpty {
                errorMessage = "No recommendations available at this time"
                setDataSourceIfNeeded(.network)
                #if DEBUG
                print("⚠️ Network returned 0 recommendations")
                #endif
            } else {
                publishIfChanged(events: events, source: .network)
                cacheService.cacheRecommendations(events)
                storageService.saveRecommendationsToStorage(events, userId: userId)
                #if DEBUG
                print("✅ \(events.count) recommendations loaded from network and cached")
                #endif
            }
        } catch {
            errorMessage = "Failed to load recommendations: \(error.localizedDescription)"
            setDataSourceIfNeeded(.none)
            #if DEBUG
            print("❌ Network error: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func triggerBackgroundRefreshIfNeeded(userId: String) {
        guard networkMonitor.isConnected else { return }
        
        let now = Date()
        if let last = lastRefreshDate, now.timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshDate = now
        
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.refreshInBackground(userId: userId)
        }
    }
    
    private func refreshInBackground(userId: String) async {
        guard networkMonitor.isConnected else { return }
        
        await MainActor.run { isRefreshing = true }
        
        do {
            let events = try await fetchRecommendationsAsync(userId: userId)
            await MainActor.run {
                isRefreshing = false
                if !events.isEmpty {
                    publishIfChanged(events: events, source: .network)
                    cacheService.cacheRecommendations(events)
                    storageService.saveRecommendationsToStorage(events, userId: userId)
                    #if DEBUG
                    print("✅ Recommendations updated in background (\(events.count) items)")
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ Background refresh returned 0 recommendations - keeping existing data")
                    #endif
                }
            }
        } catch {
            await MainActor.run {
                isRefreshing = false
                #if DEBUG
                print("⚠️ Background refresh failed: \(error.localizedDescription) - keeping existing data")
                #endif
            }
        }
    }
    
    func forceRefresh() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        cacheService.clearCache()
        
        isLoading = true
        errorMessage = nil
        dataSource = .none
        
        defer { isLoading = false }
        
        if networkMonitor.isConnected {
            await fetchFromNetwork(userId: userId)
        } else {
            if let stored = storageService.loadRecommendationsFromStorage(userId: userId), !stored.isEmpty {
                publishIfChanged(events: stored, source: .localStorage)
            } else {
                errorMessage = "No internet connection and no saved recommendations available"
            }
        }
    }
    
    func clearAllCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        cacheService.clearCache()
        storageService.clearStorage(userId: userId)
        recommendations = []
        dataSource = .none
        errorMessage = nil
        #if DEBUG
        print("🗑️ All caches cleared")
        #endif
    }
    
    func debugCache() {
        guard let userId = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("❌ No authenticated user for cache debug")
            #endif
            return
        }
        
        #if DEBUG
        print("\n" + String(repeating: "=", count: 50))
        print("RECOMMENDATION CACHE DEBUG")
        print(String(repeating: "=", count: 50))
        
        if let age = cacheService.getCacheAge() {
            let minutes = Int(age / 60)
            print("📱 Memory Cache: Active (\(minutes) minutes old)")
        } else {
            print("📱 Memory Cache: Empty")
        }
        
        let storageInfo = storageService.getStorageInfo(userId: userId)
        print("💾 Local Storage: \(storageInfo.recommendationCount) recommendations")
        if let age = storageInfo.ageInHours {
            print("   Age: \(String(format: "%.1f", age)) hours")
            print("   Status: \(storageInfo.isExpired ? "Expired" : "Valid")")
        } else {
            print("   Status: Empty")
        }
        
        print("📊 Current State:")
        print("   Recommendations loaded: \(recommendations.count)")
        print("   Data source: \(dataSource)")
        print("   Network: \(networkMonitor.isConnected ? "Connected" : "Offline")")
        if let error = errorMessage {
            print("   Error: \(error)")
        }
        
        print(String(repeating: "=", count: 50) + "\n")
        
        storageService.debugStorage(userId: userId)
        #endif
    }
    
    // MARK: - Fetch all events (for other features)
    func getAllEvents() async throws -> [Event] {
        let db = Firestore.firestore(database: "default")
        let snapshot = try await db.collection("events").getDocuments()
        
        let events: [Event] = snapshot.documents.compactMap { doc in
            EventFactory.createEvent(from: doc)
        }
        
        return events
    }
    
    // MARK: - Helpers
    private func publishIfChanged(events: [Event], source: DataSource) {
        let currentIDs = Set(recommendations.compactMap { $0.id })
        let newIDs = Set(events.compactMap { $0.id })
        guard currentIDs != newIDs else {
            setDataSourceIfNeeded(source)
            return
        }
        
        recommendations = events
        setDataSourceIfNeeded(source)
    }
    
    private func setDataSourceIfNeeded(_ newSource: DataSource) {
        if dataSource != newSource {
            dataSource = newSource
        }
    }

    // Ensure any pending background refresh task is cancelled when
    // the view model is deallocated.
    deinit {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
    }
}

