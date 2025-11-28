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
    
    private let threadManager = ThreadManager.shared
    private let networkMonitor = NetworkMonitorService.shared
    private let cacheService = NewsCacheService.shared
    private let storageService = NewsStorageService.shared
    
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
            self.errorMessage = "No internet connection and no saved profile found"
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
                // Analytics: log only on LIKE (not unlike)
                if !isCurrentlyLiked {
                    // TODO: Replace with the real AnalyticsService API if different
                    // AnalyticsService.shared.logNewsLiked(eventId: item.eventId)
                }
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

