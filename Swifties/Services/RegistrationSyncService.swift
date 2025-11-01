//
//  RegistrationSyncService.swift
//  Swifties
//
//  Handles syncing registration data from UserDefaults to Firestore
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class RegistrationSyncService: ObservableObject {
    static let shared = RegistrationSyncService()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: Error?
    
    private let db = Firestore.firestore(database: "default")
    private let userDefaultsService = UserDefaultsService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Observe network changes and try to sync when connection is restored
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { [weak self] in
                        await self?.syncPendingRegistration()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Save Registration Data with Three-Layer Strategy
    func saveRegistrationData(_ data: [String: Any]) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
        }
        
        // Layer 1: Firebase Cache (automatic)
        print("📦 Layer 1: Firebase Cache (automatic)")
        
        // Layer 2: UserDefaults (explicit local storage)
        print("💾 Layer 2: Saving to UserDefaults...")
        userDefaultsService.saveRegistrationData(data)
        
        // Layer 3: Firestore (if connected)
        if networkMonitor.isConnected {
            print("☁️ Layer 3: Attempting to save to Firestore...")
            try await uploadToFirestore(uid: uid, data: data)
        } else {
            print("⚠️ No connection - Data saved locally. Will sync when connection is restored.")
        }
    }
    
    // MARK: - Upload to Firestore
    private func uploadToFirestore(uid: String, data: [String: Any]) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            try await db.collection("users").document(uid).setData(data, merge: true)
            print("✅ Successfully saved to Firestore!")
            
            // Clear local storage after successful upload
            userDefaultsService.clearRegistrationData()
            lastSyncError = nil
        } catch {
            print("❌ Firestore save error: \(error.localizedDescription)")
            lastSyncError = error
            throw error
        }
    }
    
    // MARK: - Sync Pending Registration (called when connection is restored)
    func syncPendingRegistration() async {
        guard userDefaultsService.hasPendingRegistration() else {
            print("ℹ️ No pending registration to sync")
            return
        }
        
        guard networkMonitor.isConnected else {
            print("⚠️ Still no connection - will retry later")
            return
        }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No authenticated user - cannot sync")
            return
        }
        
        guard let pendingData = userDefaultsService.getPendingRegistrationData() else {
            print("⚠️ Failed to retrieve pending registration data")
            return
        }
        
        print("🔄 Syncing pending registration data to Firestore...")
        
        do {
            try await uploadToFirestore(uid: uid, data: pendingData)
            print("✅ Successfully synced pending registration!")
        } catch {
            print("❌ Failed to sync pending registration: \(error.localizedDescription)")
        }
    }
}