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
        if let cached = cacheService.getCachedRecommendations() {
            recommendations = cached
            dataSource = .memoryCache
            isLoading = false
            print("Recommendations loaded from memory cache")
            return
        }
        
        // Layer 2: Try local storage (SQLite)
        if let stored = storageService.loadRecommendationsFromStorage(userId: userId) {
            recommendations = stored
            dataSource = .localStorage
            isLoading = false
            
            // Cache in memory for next time
            cacheService.cacheRecommendations(stored)
            print("Recommendations loaded from local storage")
            
            // Refresh in background if connected
            await refreshInBackground(userId: userId)
            return
        }
        
        // Layer 3: Fetch from network
        if networkMonitor.isConnected {
            await fetchFromNetwork(userId: userId)
        } else {
            isLoading = false
            errorMessage = "No internet connection and no saved recommendations"
            print("No connection and no local recommendations")
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
                        self.recommendations = events
                        self.dataSource = .network
                        
                        // Save to both cache layers
                        self.cacheService.cacheRecommendations(events)
                        self.storageService.saveRecommendationsToStorage(events, userId: userId)
                        
                        print("Recommendations loaded from network and cached")
                        
                    case .failure(let error):
                        self.errorMessage = "Error loading recommendations: \(error.localizedDescription)"
                        print("Network error: \(error.localizedDescription)")
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
                    
                    if case .success(let events) = result {
                        // Update UI
                        self.recommendations = events
                        self.dataSource = .network
                        
                        // Update caches
                        self.cacheService.cacheRecommendations(events)
                        self.storageService.saveRecommendationsToStorage(events, userId: userId)
                        
                        print("Recommendations updated in background")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func forceRefresh() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        cacheService.clearCache()
        await getRecommendations()
    }
    
    func clearAllCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        cacheService.clearCache()
        storageService.clearStorage(userId: userId)
        recommendations = []
        dataSource = .none
    }
    
    func debugCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
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
