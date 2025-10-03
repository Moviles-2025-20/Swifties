//
//  AuthViewModel.swift
//  Swifties
//
//  Created on 01/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    // Published properties
    @Published var user: UserModel?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isFirstTimeUser: Bool = false
    
    // AuthService singleton
    private let authService = AuthService.shared
    let db = Firestore.firestore(database: "default")

    // Task for auth listener
    private var authListenerTask: Task<Void, Never>?
    
    // Computed properties
    var isAuthenticated: Bool {
        return user != nil
    }
    
    // Initialize and listen to auth state changes
    init() {
        startAuthListener()
    }
    
    // MARK: - Auth State Listener
    private func startAuthListener() {
        authListenerTask = Task {
            for await firebaseUser in authService.authStateChanges {
                if let firebaseUser = firebaseUser {
                    let providerId = firebaseUser.providerData.first?.providerID ?? "unknown"
                    self.user = UserModel.fromFirebase(firebaseUser, providerId: providerId)
                    await checkFirstTimeUser()
                } else {
                    self.user = nil
                    self.isFirstTimeUser = false
                }
            }
        }
    }
    
    // MARK: - Check First Time User (FIXED)
    private func checkFirstTimeUser() async {
        guard let user = user else { return }
        
        do {
            // Check if user document exists in Firestore
            let document = try await db.collection("users").document(user.uid).getDocument()
            
            // User is first-time if document doesn't exist OR doesn't have profile data
            if !document.exists {
                print("First time user - no Firestore document found")
                isFirstTimeUser = true
            } else if let data = document.data(),
                      let profile = data["profile"] as? [String: Any],
                      profile["name"] != nil {
                // Document exists and has profile data - returning user
                print("Returning user - profile found in Firestore")
                isFirstTimeUser = false
            } else {
                // Document exists but incomplete - treat as first time
                print("⚠️ Incomplete profile - treating as first time user")
                isFirstTimeUser = true
            }
        } catch {
            print("❌ Error checking user document: \(error.localizedDescription)")
            // On error, assume first time user to be safe
            isFirstTimeUser = true
        }
    }
    
    // MARK: - Login with Google
    func loginWithGoogle() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await authService.loginWithGoogle()
            self.user = UserModel.fromFirebase(result.user, providerId: result.providerId)
            self.error = nil
        } catch let authError as AuthenticationError {
            self.error = authError.localizedDescription
            self.user = nil
            print("Login error: \(authError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            self.user = nil
            print("Unexpected error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Logout
    func logout() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.logout()
            self.user = nil
        } catch {
            self.error = error.localizedDescription
            print("Logout error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Mark as Returning User
    // Call this after successful registration
    func markAsReturningUser() {
        isFirstTimeUser = false
        print("User marked as returning user")
    }
    
    // MARK: - Refresh User Status
    // Call this to manually check if user has completed registration
    func refreshUserStatus() async {
        await checkFirstTimeUser()
    }
    
    // MARK: - Delete Account
    func deleteAccount() async {
        isLoading = true
        error = nil
        
        do {
            // Delete Firestore document first
            if let uid = user?.uid {
                try await db.collection("users").document(uid).delete()
            }
            
            // Then delete auth account
            try await authService.deleteAccount()
            self.user = nil
        } catch {
            self.error = error.localizedDescription
            print("Delete account error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    
    // MARK: - Cleanup
    deinit {
        authListenerTask?.cancel()
    }
}
