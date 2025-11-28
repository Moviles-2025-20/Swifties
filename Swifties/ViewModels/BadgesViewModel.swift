//
//  BadgesViewModel.swift
//  Swifties
//
//  ViewModel for Badges Screen
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
        // MARK: - Load Badges (Three-Layer Cache)

        func loadBadges() {
            isLoading = true
            errorMessage = nil
            
            guard let userId = currentUserId else {
                isLoading = false
                errorMessage = "User not authenticated"
                return
            }
            
            print("🚀 Loading badges for user: \(userId)")
            
            // Layer 1: Try memory cache
            if let cached = cacheService.getCachedBadges(userId: userId) {
                self.combineBadgesWithProgress(badges: cached.badges, userBadges: cached.userBadges)
                self.dataSource = .memoryCache
                self.isLoading = false
                print("✅ Loaded from memory cache")
                
                // Try to refresh in background if connected
                refreshInBackground(userId: userId)
                return
            }
            
            // Layer 2: Try Realm storage
            if let stored = storageService.loadBadges(userId: userId) {
                self.combineBadgesWithProgress(badges: stored.badges, userBadges: stored.userBadges)
                self.dataSource = .localStorage
                self.isLoading = false
                
                // Cache in memory for next time
                cacheService.cacheBadges(userId: userId, badges: stored.badges, userBadges: stored.userBadges)
                
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
            networkService.fetchBadgesData(userId: userId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    switch result {
                    case .success(let data):
                        self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                        self.dataSource = .network
                        
                        // Save to both cache layers
                        self.cacheService.cacheBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                        self.storageService.saveBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                        
                        print("✅ Loaded from network and cached")
                        
                    case .failure(let error):
                        self.errorMessage = "Error loading badges: \(error.localizedDescription)"
                        print("❌ Network error: \(error.localizedDescription)")
                    }
                }
            }
        }

        private func refreshInBackground(userId: String) {
            guard networkMonitor.isConnected else { return }
            
            self.isRefreshing = true
            networkService.fetchBadgesData(userId: userId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isRefreshing = false
                    
                    if case .success(let data) = result {
                        // Update data silently
                        self.combineBadgesWithProgress(badges: data.badges, userBadges: data.userBadges)
                        
                        // Update caches for next time
                        self.cacheService.cacheBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                        self.storageService.saveBadges(userId: userId, badges: data.badges, userBadges: data.userBadges)
                        
                        print("✅ Updated in background")
                    }
                }
            }
        }

        // MARK: - Helper Methods

        private func combineBadgesWithProgress(badges: [Badge], userBadges: [UserBadge]) {
            self.badgesWithProgress = badges.compactMap { badge in
                if let userBadge = userBadges.first(where: { $0.badgeId == badge.id }) {
                    return BadgeWithProgress(badge: badge, userBadge: userBadge)
                }
                return nil
            }.sorted { $0.badge.rarity.rawValue > $1.badge.rarity.rawValue }
        }

        // MARK: - Cache Management

        func forceRefresh() {
            guard let userId = currentUserId else { return }
            cacheService.clearCache(userId: userId)
            storageService.deleteBadges(userId: userId)
            loadBadges()
        }

        func clearAllCache() {
            guard let userId = currentUserId else { return }
            cacheService.clearCache(userId: userId)
            storageService.deleteBadges(userId: userId)
            badgesWithProgress = []
            dataSource = .none
        }

        func debugCache() {
            guard let userId = currentUserId else { return }
            cacheService.debugCache(userId: userId)
            storageService.debugStorage(userId: userId)
        }
        }

