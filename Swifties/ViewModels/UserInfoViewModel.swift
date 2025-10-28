//
//  UserInfoViewModel.swift
//  Swifties
//
//  Created by Imac on 28/10/25.
//

import SwiftUI
import FirebaseAuth
import Combine

class UserInfoViewModel: ObservableObject {
    @Published var freeTimeSlots: [FreeTimeSlot] = []
    @Published var availableEvents: [Event] = []
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
    
    private let cacheService = UserEventCacheService.shared
    private let storageService = UserEventStorageService.shared
    private let networkService = UserEventNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    init() {}
    
    // MARK: - Load Data (Three-Layer Cache)
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "No authenticated user"
            return
        }
        
        // Layer 1: Try memory cache
        if let cached = cacheService.getCachedUserEvents() {
            self.availableEvents = cached.availableEvents
            self.freeTimeSlots = cached.freeTimeSlots
            self.dataSource = .memoryCache
            self.isLoading = false
            print("User events loaded from memory cache")
            return
        }
        
        // Layer 2: Try local storage (SQLite)
        if let stored = storageService.loadUserEventsFromStorage(userId: userId) {
            self.availableEvents = stored.events
            self.freeTimeSlots = stored.slots
            self.dataSource = .localStorage
            self.isLoading = false
            
            // Cache in memory for next time
            cacheService.cacheUserEvents(stored.events, freeTimeSlots: stored.slots)
            print("User events loaded from local storage")
            
            // Refresh in background if connected
            refreshInBackground(userId: userId)
            return
        }
        
        // Layer 3: Fetch from network
        if networkMonitor.isConnected {
            fetchFromNetwork(userId: userId)
        } else {
            isLoading = false
            errorMessage = "No internet connection and no saved data found"
            print("No connection and no local user events")
        }
    }
    
    private func fetchFromNetwork(userId: String) {
        networkService.fetchUserEvents { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                switch result {
                case .success(let data):
                    self.availableEvents = data.events
                    self.freeTimeSlots = data.slots
                    self.dataSource = .network
                    
                    // Save to both cache layers
                    self.cacheService.cacheUserEvents(data.events, freeTimeSlots: data.slots)
                    self.storageService.saveUserEventsToStorage(
                        data.events,
                        freeTimeSlots: data.slots,
                        userId: userId
                    )
                    
                    print("User events loaded from network and cached")
                    
                case .failure(let error):
                    self.errorMessage = "Error loading user events: \(error.localizedDescription)"
                    print("Network error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func refreshInBackground(userId: String) {
        guard networkMonitor.isConnected else { return }
        
        self.isRefreshing = true
        networkService.fetchUserEvents { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                
                if case .success(let data) = result {
                    // Update UI
                    self.availableEvents = data.events
                    self.freeTimeSlots = data.slots
                    self.dataSource = .network
                    
                    // Update caches
                    self.cacheService.cacheUserEvents(data.events, freeTimeSlots: data.slots)
                    self.storageService.saveUserEventsToStorage(
                        data.events,
                        freeTimeSlots: data.slots,
                        userId: userId
                    )
                    
                    print("User events updated in background")
                }
            }
        }
    }
    
    func forceRefresh() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        cacheService.clearCache()
        loadData()
    }
    
    func clearAllCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        cacheService.clearCache()
        storageService.clearStorage(userId: userId)
        availableEvents = []
        freeTimeSlots = []
        dataSource = .none
    }
    
    func debugCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        storageService.debugStorage(userId: userId)
    }
}
