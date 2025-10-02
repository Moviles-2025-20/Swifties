//
//  AuthViewModel.swift
//  Swifties
//
//  Created on 01/10/25.
//

import Foundation
import FirebaseAuth
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
    
    // MARK: - Check First Time User
    private func checkFirstTimeUser() async {
        guard let user = user else { return }
        
        let key = "user_\(user.uid)_has_loggedin"
        let hasLoggedInBefore = UserDefaults.standard.bool(forKey: key)
        
        isFirstTimeUser = !hasLoggedInBefore
        
        if isFirstTimeUser {
            // Mark user as having logged in
            UserDefaults.standard.set(true, forKey: key)
        }
    }
    
    // MARK: - Login with Google
    func loginWithGoogle() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await authService.loginWithGoogle()
            self.user = UserModel.fromFirebase(result.user, providerId: result.providerId)
        } catch let authError as AuthenticationError {
            self.error = authError.localizedDescription
            self.user = nil
            print("Google login error: \(authError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            self.user = nil
            print("Unexpected Google login error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Login with GitHub
    func loginWithGitHub() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await authService.loginWithGitHub()
            self.user = UserModel.fromFirebase(result.user, providerId: result.providerId)
        } catch let authError as AuthenticationError {
            self.error = authError.localizedDescription
            self.user = nil
            print("GitHub login error: \(authError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            self.user = nil
            print("Unexpected GitHub login error: \(error.localizedDescription)")
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
    
    // MARK: - Mark as Returning User (optional)
    func markAsReturningUser() {
        guard let user = user else { return }
        
        let key = "user_\(user.uid)_has_loggedin"
        UserDefaults.standard.set(true, forKey: key)
        isFirstTimeUser = false
    }
    
    // MARK: - Delete Account
    func deleteAccount() async {
        isLoading = true
        error = nil
        
        do {
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
