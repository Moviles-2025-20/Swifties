//
//  NewsViewModel.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 27/11/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

class NewsViewModel: ObservableObject {
    @Published var news: [News] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    
    // Selection/navigation state for Event detail
    @Published var isSelectingEvent: Bool = false
    @Published var selectedEvent: Event?
    @Published var isPresentingEventDetail: Bool = false
    
    private let threadManager = ThreadManager.shared
    private let networkMonitor = NetworkMonitorService.shared
    private let cacheService = NewsCacheService.shared
    private let storageService = NewsStorageService.shared
    
    // Event stack (reuse Event List services)
    private let eventCacheService = EventCacheService.shared
    private let eventStorageService = EventStorageService.shared
    private let eventNetworkService = EventNetworkService.shared
    
    private let db = Firestore.firestore(database: "default")
    
    enum DataSource {
        case none
        case memoryCache
        case localStorage
        case network
    }
    
    func loadNews() {
        threadManager.executeOnMain { [weak self] in
            self?.isLoading = true
            self?.errorMessage = nil
        }
        
        // 1) Memory cache
        if let cached = cacheService.getCachedNews() {
            self.news = cached
            self.dataSource = .memoryCache
            self.isLoading = false
            refreshInBackground()
            return
        }

        // 2) Local storage
        if let stored = storageService.getStoredNews() {
            self.news = stored
            self.dataSource = .localStorage
            self.isLoading = false
            refreshInBackground()
            return
        }

        // 3) Network
        guard networkMonitor.isConnected else {
            self.isLoading = false
            self.errorMessage = "No internet connection and no saved news found"
            return
        }
        
        fetchNewsFromNetwork { [weak self] result in
            guard let self = self else { return }
            self.threadManager.executeOnMain {
                self.isLoading = false
                switch result {
                case .success(let fetched):
                    self.news = fetched
                    self.dataSource = .network
                    // Save to cache and local storage
                    self.threadManager.writeToCache {
                        self.cacheService.cacheNews(fetched)
                    }
                    self.threadManager.executeDatabaseOperation {
                        self.storageService.saveNews(fetched)
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func refreshInBackground() {
        guard networkMonitor.isConnected else { return }
        isRefreshing = true
        threadManager.executeNetworkOperation { [weak self] in
            guard let self = self else { return }
            self.fetchNewsFromNetwork { result in
                switch result {
                case .success(let fetched):
                    self.threadManager.writeToCache {
                        self.cacheService.cacheNews(fetched)
                    }
                    self.threadManager.executeDatabaseOperation {
                        self.storageService.saveNews(fetched)
                    }
                    self.threadManager.executeOnMain {
                        self.news = fetched
                        self.dataSource = .network
                        self.isRefreshing = false
                    }
                case .failure:
                    self.threadManager.executeOnMain {
                        self.isRefreshing = false
                    }
                }
            }
        }
    }
    
    // MARK: - Toggle Like (like or unlike based on current state)
    func toggleLike(_ item: News) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "No authenticated user"
            return
        }
        guard let docId = item.id, !docId.isEmpty else {
            self.errorMessage = "Invalid news id"
            return
        }
        
        let isCurrentlyLiked = item.ratings.contains(uid)
        let applyLocalChange: (_ add: Bool) -> Void = { add in
            if let idx = self.news.firstIndex(where: { $0.id == item.id }) {
                var updated = self.news[idx]
                if add {
                    if !updated.ratings.contains(uid) {
                        updated.ratings.append(uid)
                    }
                } else {
                    updated.ratings.removeAll { $0 == uid }
                }
                self.news[idx] = updated
            }
            // Keep cache and storage in sync
            self.threadManager.writeToCache {
                self.cacheService.cacheNews(self.news)
            }
            self.threadManager.executeDatabaseOperation {
                self.storageService.saveNews(self.news)
            }
        }
        
        // Optimistic update
        applyLocalChange(!isCurrentlyLiked)
        
        // Persist to Firestore
        let update: [String: Any] = isCurrentlyLiked
            ? ["ratings": FieldValue.arrayRemove([uid])]
            : ["ratings": FieldValue.arrayUnion([uid])]
        
        db.collection("news").document(docId).updateData(update) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                // Roll back optimistic update
                applyLocalChange(isCurrentlyLiked)
                self.threadManager.executeOnMain {
                    self.errorMessage = "Failed to update like: \(error.localizedDescription)"
                }
            } else {
                // Analytics: log on like
                if !isCurrentlyLiked {
                    // Resolve the corresponding event to obtain its category, then log
                    self.resolveEventById(item.eventId) { event in
                        let category = event?.category ?? "unknown"
                        let activityId = event?.id ?? item.eventId
                        AnalyticsService.shared.logEventSelected(eventId: activityId, category: category)
                    }
                }
            }
        }
    }
    
    // MARK: - Selection: Load Event by news.eventId and present detail
    func selectNews(_ item: News) {
        let eventId = item.eventId
        guard !eventId.isEmpty else {
            threadManager.executeOnMain { [weak self] in
                self?.errorMessage = "Invalid event id"
            }
            return
        }
        
        threadManager.executeOnMain { [weak self] in
            self?.isSelectingEvent = true
            self?.errorMessage = nil
            self?.selectedEvent = nil
        }
        
        // 1) Try memory cache
        threadManager.readFromCache(operation: { [weak self] () -> Event? in
            guard let self = self else { return nil }
            return self.eventCacheService.getCachedEvents()?.first(where: { $0.id == eventId })
        }, completion: { [weak self] (cached: Event?) in
            guard let self = self else { return }
            if let cached = cached {
                self.finishSelection(with: cached)
                return
            }
            // 2) Try local storage (load all then filter)
            self.eventStorageService.loadEventsFromStorage { [weak self] storedList in
                guard let self = self else { return }
                if let event = storedList?.first(where: { $0.id == eventId }) {
                    // refresh cache with the full list if available
                    if let storedList = storedList {
                        self.threadManager.writeToCache {
                            self.eventCacheService.cacheEvents(storedList)
                        }
                    }
                    self.finishSelection(with: event)
                    return
                }
                // 3) Network (if connected): fetch all events and filter
                guard self.networkMonitor.isConnected else {
                    self.threadManager.executeOnMain {
                        self.isSelectingEvent = false
                        self.errorMessage = "Event not found offline"
                    }
                    return
                }
                self.eventNetworkService.fetchEvents { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let events):
                        // Update cache
                        self.threadManager.writeToCache {
                            self.eventCacheService.cacheEvents(events)
                        }
                        self.eventStorageService.saveEventsToStorage(events, completion: nil)
                        if let found = events.first(where: { $0.id == eventId }) {
                            self.finishSelection(with: found)
                        } else {
                            self.threadManager.executeOnMain {
                                self.isSelectingEvent = false
                                self.errorMessage = "Event not found: id did not match any other"
                            }
                        }
                    case .failure(let error):
                        self.threadManager.executeOnMain {
                            self.isSelectingEvent = false
                            self.errorMessage = "Failed to load event: \(error.localizedDescription)"
                        }
                    }
                }
            }
        })
    }
    
    private func finishSelection(with event: Event) {
        threadManager.executeOnMain { [weak self] in
            self?.selectedEvent = event
            self?.isSelectingEvent = false
            self?.isPresentingEventDetail = true
        }
    }
    
    // Helper: resolve an Event by id using cache -> storage -> network, then call completion on main
    private func resolveEventById(_ eventId: String, completion: @escaping (Event?) -> Void) {
        // Cache first
        threadManager.readFromCache(operation: { [weak self] () -> Event? in
            guard let self = self else { return nil }
            return self.eventCacheService.getCachedEvents()?.first(where: { $0.id == eventId })
        }, completion: { [weak self] (cached: Event?) in
            guard let self = self else { return }
            if let cached = cached {
                self.threadManager.executeOnMain { completion(cached) }
                return
            }
        })
        // Local storage
        self.eventStorageService.loadEventsFromStorage { [weak self] stored in
            guard let self = self else { return }
            if let event = stored?.first(where: { $0.id == eventId }) {
                if let stored = stored {
                    self.threadManager.writeToCache {
                        self.eventCacheService.cacheEvents(stored)
                    }
                }
                self.threadManager.executeOnMain { completion(event) }
                return
            }
        }
        // Network if connected
        guard self.networkMonitor.isConnected else {
            self.threadManager.executeOnMain { completion(nil) }
            return
        }
        self.eventNetworkService.fetchEvents { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let events):
                self.threadManager.writeToCache {
                    self.eventCacheService.cacheEvents(events)
                }
                self.eventStorageService.saveEventsToStorage(events, completion: nil)
                let found = events.first(where: { $0.id == eventId })
                self.threadManager.executeOnMain { completion(found) }
            case .failure:
                self.threadManager.executeOnMain { completion(nil) }
            }
        }
    }
    
    // MARK: - Network
    private func fetchNewsFromNetwork(completion: @escaping (Result<[News], Error>) -> Void) {
        db.collection("news").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let snapshot = snapshot else {
                completion(.success([]))
                return
            }
            let items: [News] = snapshot.documents.compactMap { NewsFactory.createNews(from: $0) }
            completion(.success(items))
        }
    }
}

