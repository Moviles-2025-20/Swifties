//
//  QuizSyncService.swift
//  Swifties
//
//  Handles syncing pending quiz results when connectivity is restored
//

import Foundation
import Combine

@MainActor
class QuizSyncService: ObservableObject {
    static let shared = QuizSyncService()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: Error?
    
    private let networkService = QuizNetworkService.shared
    private let storageService = QuizStorageService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Observe network changes and sync when connection is restored
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    print("🌐 Network connection restored - checking for pending quiz results...")
                    Task { [weak self] in
                        await self?.syncPendingResults()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Pending Results
    
    func syncPendingResults() async {
        guard storageService.hasPendingResults() else {
            print("ℹ️ No pending quiz results to sync")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("⚠️ Still no connection - will retry later")
            return
        }
        
        let pendingResults = storageService.loadPendingResults()
        
        guard !pendingResults.isEmpty else {
            return
        }
        
        print("🔄 Syncing \(pendingResults.count) pending quiz results to Firestore...")
        isSyncing = true
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            networkService.syncPendingResults(results: pendingResults) { [weak self] result in
                Task { @MainActor in
                    defer { 
                        self?.isSyncing = false
                        continuation.resume()
                    }
                    
                    switch result {
                    case .success:
                        print("✅ Successfully synced pending quiz results!")
                        self?.storageService.clearPendingResults()
                        self?.lastSyncError = nil
                        
                        // Post notification
                        NotificationCenter.default.post(name: .quizSyncCompleted, object: nil)
                        
                    case .failure(let error):
                        print("❌ Failed to sync pending quiz results: \(error.localizedDescription)")
                        self?.lastSyncError = error
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Sync Trigger
    
    func triggerManualSync() async {
        print("🔄 Manual quiz sync triggered...")
        await syncPendingResults()
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let quizSyncCompleted = Notification.Name("quizSyncCompleted")
}