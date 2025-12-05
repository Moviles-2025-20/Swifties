//
//  RegistrationSyncService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 31/10/25.
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
    
    // ISO8601 formatter for date conversion
    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private init() {
        // Observe network changes and try to sync when connection is restored
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    print("[NETWORKKK] Network connection restored - checking for pending registration...")
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
            // Convert date strings to Firestore Timestamps before uploading
            var firestoreData = data
            
            // Convert profile dates
            if var profile = firestoreData["profile"] as? [String: Any] {
                if let createdString = profile["created"] as? String,
                   let createdDate = iso8601Formatter.date(from: createdString) {
                    profile["created"] = Timestamp(date: createdDate)
                }
                if let lastActiveString = profile["last_active"] as? String,
                   let lastActiveDate = iso8601Formatter.date(from: lastActiveString) {
                    profile["last_active"] = Timestamp(date: lastActiveDate)
                }
                firestoreData["profile"] = profile
            }
            
            try await db.collection("users").document(uid).setData(firestoreData, merge: true)
            print("✅ Successfully saved to Firestore!")
            
            // CRITICAL: Clear pending data AFTER successful Firestore upload
            userDefaultsService.clearRegistrationData()
            lastSyncError = nil
            
            // Notify that sync completed successfully
            NotificationCenter.default.post(name: .registrationSyncCompleted, object: nil)
            
        } catch {
            print("❌ Firestore save error: \(error.localizedDescription)")
            lastSyncError = error
            throw error
        }
    }
    
    // MARK: - Sync Pending Registration (called when connection is restored)
    func syncPendingRegistration() async {
        guard userDefaultsService.hasPendingRegistration() else {
            print("!!!!!!! No pending registration to sync")
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
        
        print("[SYNC] Syncing pending registration data to Firestore...")
        
        do {
            try await uploadToFirestore(uid: uid, data: pendingData)
            print("✅ Successfully synced pending registration!")
        } catch {
            print("❌ Failed to sync pending registration: \(error.localizedDescription)")
            lastSyncError = error
        }
    }
    
    // MARK: - Manual Sync Trigger
    func triggerManualSync() async {
        print("[SYNC] Manual sync triggered...")
        await syncPendingRegistration()
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let registrationSyncCompleted = Notification.Name("registrationSyncCompleted")
}
