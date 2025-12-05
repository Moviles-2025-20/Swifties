//
//  QuizSyncService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/11/25.
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
                    print("[BACK ONLINE] Network connection restored - checking for pending quiz results...")
                    Task { [weak self] in
                        await self?.syncPendingResults()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Pending Results
    
    func syncPendingResults() async {
        // IMPORTANT FIX: Always check storage, not just local state
        guard storageService.hasPendingResults() else {
            print("-->> No pending quiz results to sync")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("⚠️ [NOT CONNECTED] Still no connection - will retry later")
            return
        }
        
        let pendingResults = storageService.loadPendingResults()
        
        guard !pendingResults.isEmpty else {
            print("⚠️ Storage reports pending results but load returned empty array")
            return
        }
        
        print("[SYNC START] Syncing \(pendingResults.count) pending quiz result(s) to Firestore...")
        isSyncing = true
        
        // Continuation for proper async/await with callback-based API
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            networkService.syncPendingResults(results: pendingResults) { [weak self] result in
                Task { @MainActor in
                    defer {
                        self?.isSyncing = false
                        continuation.resume()
                    }
                    
                    switch result {
                    case .success:
                        print("✅ [SYNC SUCCESS] Successfully synced \(pendingResults.count) quiz result(s)!")
                        
                        // CRITICAL: Clear pending data AFTER successful Firestore upload
                        self?.storageService.clearPendingResults()
                        self?.lastSyncError = nil
                        
                        // Notify that sync completed successfully
                        NotificationCenter.default.post(name: .quizSyncCompleted, object: nil)
                        print("[NOTIFICATION] Posted quizSyncCompleted notification")
                        
                    case .failure(let error):
                        print("❌ [SYNC FAILED] Failed to sync pending quiz results: \(error.localizedDescription)")
                        self?.lastSyncError = error
                        
                        // Results remain in storage for retry
                        print("!!!!!! Results remain in storage for retry")
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Sync Trigger
    
    func triggerManualSync() async {
        print("[MANUAL] Manual quiz sync triggered...")
        await syncPendingResults()
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let quizSyncCompleted = Notification.Name("quizSyncCompleted")
}
