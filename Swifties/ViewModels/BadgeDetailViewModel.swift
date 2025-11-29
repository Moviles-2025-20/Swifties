//
//  BadgeDetailViewModel.swift
//  Swifties
//
//  ViewModel for Badge Detail with Three-Layer Cache
//

import Foundation
import Combine

@MainActor
class BadgeDetailViewModel: ObservableObject {
    @Published var badgeDetail: BadgeDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    
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
    
    // MARK: - Load Badge Detail (Three-Layer Cache)
    
    func loadBadgeDetail() {
        isLoading = true
        errorMessage = nil
        
        print("🚀 Loading badge detail: \(badgeId) for user: \(userId)")
        
        // Layer 1: Memory Cache
        if let cached = cacheService.getCachedDetail(badgeId: badgeId, userId: userId) {
            self.badgeDetail = cached
            self.dataSource = .memoryCache
            self.isLoading = false
            print("✅ Loaded from memory cache")
            
            // Try to refresh in background if connected
            refreshInBackground()
            return
        }
        
        // Layer 2: Local Storage (SQLite via Realm)
        if let stored = storageService.loadDetail(badgeId: badgeId, userId: userId) {
            self.badgeDetail = stored
            self.dataSource = .localStorage
            self.isLoading = false
            
            // Cache in memory
            cacheService.cacheDetail(badgeId: badgeId, userId: userId, detail: stored)
            
            print("✅ Loaded from local storage")
            
            // Try to refresh in background if connected
            refreshInBackground()
            return
        }
        
        // Layer 3: Network
        if networkMonitor.isConnected {
            fetchFromNetwork()
        } else {
            isLoading = false
            errorMessage = "No internet connection and no cached data available"
            print("❌ No connection and no local data")
        }
    }
    
    private func fetchFromNetwork() {
        networkService.fetchBadgeDetail(badgeId: badgeId, userId: userId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let detail):
                    self.badgeDetail = detail
                    self.dataSource = .network
                    
                    // Save to both cache layers
                    self.cacheService.cacheDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                    self.storageService.saveDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                    
                    print("✅ Loaded from network and cached")
                    
                case .failure(let error):
                    self.errorMessage = "Error loading badge detail: \(error.localizedDescription)"
                    print("❌ Network error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func refreshInBackground() {
        guard networkMonitor.isConnected else { return }
        
        networkService.fetchBadgeDetail(badgeId: badgeId, userId: userId) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                if case .success(let detail) = result {
                    self.badgeDetail = detail
                    
                    // Update caches
                    self.cacheService.cacheDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                    self.storageService.saveDetail(badgeId: self.badgeId, userId: self.userId, detail: detail)
                    
                    print("✅ Updated in background")
                }
            }
        }
    }
}
