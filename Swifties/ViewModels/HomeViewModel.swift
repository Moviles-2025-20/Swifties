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
    
    enum DataSource {
        case none
        case memoryCache
        case localStorage
        case network
    }
    
    private let cacheService = RecommendationCacheService.shared
    private let storageService = RecommendationStorageService.shared
    private let networkService = RecommendationNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    init() {}
    
    // MARK: - Load Recommendations (Three-Layer Cache)
    
    func getRecommendations() async {
        isLoading = true
        errorMessage = nil
        
        guard let userId = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                isLoading = false
                errorMessage = "No authenticated user"
            }
            return
        }
        
        // Layer 1: Try memory cache
        if let cached = cacheService.getCachedRecommendations(), !cached.isEmpty {
            recommendations = cached
            dataSource = .memoryCache
            isLoading = false
            print("✅ Recommendations loaded from memory cache (\(cached.count) items)")
            
            // Refresh in background if connected
            await refreshInBackground(userId: userId)
            return
        }
        
        // Layer 2: Try local storage (SQLite)
        if let stored = storageService.loadRecommendationsFromStorage(userId: userId), !stored.isEmpty {
            recommendations = stored
            dataSource = .localStorage
            isLoading = false
            
            // Cache in memory for next time
            cacheService.cacheRecommendations(stored)
            print("✅ Recommendations loaded from local storage (\(stored.count) items)")
            
            // Refresh in background if connected
            await refreshInBackground(userId: userId)
            return
        }
        
        // Layer 3: Fetch from network
        if networkMonitor.isConnected {
            await fetchFromNetwork(userId: userId)
        } else {
            isLoading = false
            errorMessage = "No internet connection and no saved recommendations available"
            dataSource = .none
            print("❌ No connection and no local recommendations")
        }
    }
    
    private func fetchFromNetwork(userId: String) async {
        await withCheckedContinuation { continuation in
            networkService.fetchRecommendations(userId: userId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.isLoading = false
                    
                    switch result {
                    case .success(let events):
                        if events.isEmpty {
                            // Network returned empty array
                            self.errorMessage = "No recommendations available at this time"
                            self.dataSource = .network
                            print("⚠️ Network returned 0 recommendations")
                        } else {
                            // Success with data
                            self.recommendations = events
                            self.dataSource = .network
                            
                            // Save to both cache layers
                            self.cacheService.cacheRecommendations(events)
                            self.storageService.saveRecommendationsToStorage(events, userId: userId)
                            
                            print("✅ \(events.count) recommendations loaded from network and cached")
                        }
                        
                    case .failure(let error):
                        self.errorMessage = "Failed to load recommendations: \(error.localizedDescription)"
                        self.dataSource = .none
                        print("❌ Network error: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func refreshInBackground(userId: String) async {
        guard networkMonitor.isConnected else { return }
        
        isRefreshing = true
        
        await withCheckedContinuation { continuation in
            networkService.fetchRecommendations(userId: userId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.isRefreshing = false
                    
                    if case .success(let events) = result, !events.isEmpty {
                        // Update UI only if we got valid data
                        self.recommendations = events
                        self.dataSource = .network
                        
                        // Update caches
                        self.cacheService.cacheRecommendations(events)
                        self.storageService.saveRecommendationsToStorage(events, userId: userId)
                        
                        print("✅ Recommendations updated in background (\(events.count) items)")
                    } else if case .success(let events) = result, events.isEmpty {
                        print("⚠️ Background refresh returned 0 recommendations - keeping existing data")
                    } else if case .failure(let error) = result {
                        print("⚠️ Background refresh failed: \(error.localizedDescription) - keeping existing data")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func forceRefresh() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Clear caches to force network fetch
        cacheService.clearCache()
        
        // Show loading state
        isLoading = true
        errorMessage = nil
        dataSource = .none
        
        await getRecommendations()
    }
    
    func clearAllCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        cacheService.clearCache()
        storageService.clearStorage(userId: userId)
        recommendations = []
        dataSource = .none
        errorMessage = nil
        print("🗑️ All caches cleared")
    }
    
    func debugCache() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for cache debug")
            return
        }
        
        print("\n" + String(repeating: "=", count: 50))
        print("RECOMMENDATION CACHE DEBUG")
        print(String(repeating: "=", count: 50))
        
        // Memory cache info
        if let age = cacheService.getCacheAge() {
            let minutes = Int(age / 60)
            print("📱 Memory Cache: Active (\(minutes) minutes old)")
        } else {
            print("📱 Memory Cache: Empty")
        }
        
        // Storage info
        let storageInfo = storageService.getStorageInfo(userId: userId)
        print("💾 Local Storage: \(storageInfo.recommendationCount) recommendations")
        if let age = storageInfo.ageInHours {
            print("   Age: \(String(format: "%.1f", age)) hours")
            print("   Status: \(storageInfo.isExpired ? "Expired" : "Valid")")
        } else {
            print("   Status: Empty")
        }
        
        // Current state
        print("📊 Current State:")
        print("   Recommendations loaded: \(recommendations.count)")
        print("   Data source: \(dataSource)")
        print("   Network: \(networkMonitor.isConnected ? "Connected" : "Offline")")
        if let error = errorMessage {
            print("   Error: \(error)")
        }
        
        print(String(repeating: "=", count: 50) + "\n")
        
        // Detailed database debug
        storageService.debugStorage(userId: userId)
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
}
