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
    @Published var user: UserAuthModel?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isFirstTimeUser: Bool = false
    @Published var isEmailVerified: Bool = false
    @Published var isCheckingProfile: Bool = true
    
    
    // AuthService singleton
    private let authService = AuthService.shared
    let db = Firestore.firestore(database: "default")
    
    // Offline support services
    private let userDefaultsService = UserDefaultsService.shared
    private let networkMonitor = NetworkMonitorService.shared
    private var cancellables = Set<AnyCancellable>()

    // Task for auth listener
    private var authListenerTask: Task<Void, Never>?
    
    // Computed properties
    var isAuthenticated: Bool {
        return user != nil
    }
    
    // Initialize and listen to auth state changes
    init() {
        startAuthListener()
        observeNetworkChanges()
    }
    
    // MARK: - Observe Network Changes
    private func observeNetworkChanges() {
        // Listen for successful sync completion
        NotificationCenter.default.publisher(for: .registrationSyncCompleted)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    print("🔄 Registration sync completed - rechecking user status...")
                    await self.recheckUserStatus()
                }
            }
            .store(in: &cancellables)
        
        // Listen for network connection restoration
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                guard let _ = self, isConnected else { return }
                Task { @MainActor in
                    print("🌐 Network restored - attempting to sync pending data...")
                    await RegistrationSyncService.shared.syncPendingRegistration()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auth State Listener
    private func startAuthListener() {
        authListenerTask = Task {
            for await firebaseUser in authService.authStateChanges {
                if let firebaseUser = firebaseUser {
                    let providerId = firebaseUser.providerData.first?.providerID ?? "unknown"
                    self.user = UserAuthModel.fromFirebase(firebaseUser, providerId: providerId)
                    self.isEmailVerified = firebaseUser.isEmailVerified
                    await checkFirstTimeUser()
                } else {
                    self.user = nil
                    self.isFirstTimeUser = false
                    self.isCheckingProfile = false
                }
            }
        }
    }
    
    // MARK: - Check First Time User (WITH IMPROVED OFFLINE SUPPORT)
    private func checkFirstTimeUser() async {
        guard let user = user else {
            isCheckingProfile = false
            return
        }
        
        isCheckingProfile = true
        defer { isCheckingProfile = false }
        
        print("🔍 Checking first time user status for: \(user.uid)")
        
        // Check user-specific registration flag first, then fall back to global registration flag
        // First check: Has this specific user completed registration?
        if userDefaultsService.hasCompletedRegistration(uid: user.uid) {
            print("✅ Found cached registration status for user \(user.uid) - treating as returning user")
            self.isFirstTimeUser = false
            
            // If we have pending data to sync, try syncing it now
            if userDefaultsService.hasPendingRegistration() && networkMonitor.isConnected {
                print("🔄 Found pending registration data - attempting to sync...")
                await RegistrationSyncService.shared.syncPendingRegistration()
            }
            return
        }
        
        // Second check: Has ANY registration been completed locally?
        // This catches the case where the user completed registration offline
        if userDefaultsService.hasCompletedRegistrationLocally() {
            print("✅ Found completed registration in UserDefaults - treating as returning user")
            // IMPORTANT: Also cache this for the specific user
            userDefaultsService.cacheRegistrationStatus(uid: user.uid, completed: true)
            self.isFirstTimeUser = false
            
            // If we have pending data to sync, try syncing it now
            if userDefaultsService.hasPendingRegistration() && networkMonitor.isConnected {
                print("🔄 Found pending registration data - attempting to sync...")
                await RegistrationSyncService.shared.syncPendingRegistration()
            }
            return
        }
        
        // Check Firestore if online
        if networkMonitor.isConnected {
            do {
                let document = try await db.collection("users").document(user.uid).getDocument()
                
                // User is first-time if document doesn't exist OR doesn't have profile data
                if !document.exists {
                    print("First time user - no Firestore document found")
                    isFirstTimeUser = true
                    // Cache this status
                    userDefaultsService.cacheRegistrationStatus(uid: user.uid, completed: false)
                } else if let data = document.data(),
                          let profile = data["profile"] as? [String: Any],
                          profile["name"] != nil {
                    // Document exists and has profile data - returning user
                    print("Returning user - profile found in Firestore")
                    isFirstTimeUser = false
                    // IMPORTANT: Cache this status for offline use
                    userDefaultsService.cacheRegistrationStatus(uid: user.uid, completed: true)
                    userDefaultsService.markRegistrationCompleted()
                } else {
                    // Document exists but incomplete - treat as first time
                    print("==== Incomplete profile - treating as first time user")
                    isFirstTimeUser = true
                    userDefaultsService.cacheRegistrationStatus(uid: user.uid, completed: false)
                }
            } catch {
                print("❌ Error checking user document: \(error.localizedDescription)")
                
                // On error while online, check if we have cached status to fall back on
                if userDefaultsService.hasCompletedRegistration(uid: user.uid) {
                    print("==== Using cached registration status due to Firestore error")
                    isFirstTimeUser = false
                } else {
                    // No cached data and error - assume first time to be safe
                    isFirstTimeUser = true
                }
            }
        } else {
            // Offline - check if we have cached status for this specific user
            if userDefaultsService.hasCompletedRegistration(uid: user.uid) {
                print("Offline - using cached registration status: User has completed registration")
                isFirstTimeUser = false
            } else {
                print("=-==== Offline with no cached registration status - treating as first time user")
                print("-==== This can happen after reinstall. User should connect to internet once to verify.")
                isFirstTimeUser = true
            }
        }
    }
    
    // MARK: - Recheck User Status (after sync)
    private func recheckUserStatus() async {
        guard let _ = user?.uid else { return }
        print("🔄 Rechecking user status after sync...")
        await checkFirstTimeUser()
    }
    
    // MARK: - Auth Providers
    enum AuthProvider {
        case google
        case email
        case twitter
        
        var displayName: String {
            switch self {
            case .google: return "Google"
            case .email: return "Email"
            case .twitter: return "Twitter"
            }
        }
    }

    // MARK: - Unified Login
    @MainActor
    func login(with provider: AuthProvider, email: String = "", password: String = "") async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let result: (user: FirebaseAuth.User, providerId: String)
            switch provider {
            case .google:
                result = try await authService.loginWithGoogle()
            case .email:
                result = try await authService.loginWithEmail(email: email, password: password)
            case .twitter:
                result = try await authService.loginWithTwitter()
            }
            self.user = UserAuthModel.fromFirebase(result.user, providerId: result.providerId)
            self.isEmailVerified = result.user.isEmailVerified
        } catch let authError as AuthenticationError {
            self.error = authError.localizedDescription
            self.user = nil
            print("\(provider.displayName) login error: \(authError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            self.user = nil
            print("Unexpected \(provider.displayName) login error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Password Reset
    func sendPasswordReset(email: String) async {
        isLoading = true
        error = nil
        
        do {
            try await authService.sendPasswordReset(email: email)
            print("Password reset link sent")
        } catch let authError as AuthenticationError {
            self.error = authError.localizedDescription
            print("Password reset error: \(authError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            print("Unexpected error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: Validity for password and email
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPredicate.evaluate(with: email)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        let passwordRegEx = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[A-Za-z\\d@$!%*?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegEx)
        return passwordPredicate.evaluate(with: password)
    }
    
    // MARK: - Register with Email
    func registerWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil

        guard isValidEmail(email) else {
            self.error = "Please enter a valid email address."
            isLoading = false
            return
        }
            
        guard isValidPassword(password) else {
            self.error = "Password must be at least 8 characters, include uppercase, lowercase, and a number."
            isLoading = false
            return
        }
        
        do {
            let result = try await authService.registerWithEmail(email: email, password: password)
            self.user = UserAuthModel.fromFirebase(result.user, providerId: result.providerId)
            self.isEmailVerified = result.user.isEmailVerified
        } catch let authError as AuthenticationError {
            self.error = authError.localizedDescription
            self.user = nil
            print("Registration error: \(authError.localizedDescription)")
        } catch {
            self.error = error.localizedDescription
            self.user = nil
            print("Unexpected error: \(error.localizedDescription)")
        }

        isLoading = false
    }
    
    func resendVerificationEmail() async {
        do {
            try await authService.resendVerificationEmail()
        } catch {
            self.error = error.localizedDescription
            print("Resend verification email error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Login with Google
    @MainActor
    func loginWithGoogle() async {
        await login(with: .google)
    }
    
    // MARK: - Login with Email
    @MainActor
    func loginWithEmail(email: String, password: String) async {
        await login(with: .email, email: email, password: password)
    }
    
    // MARK: - Login with Twitter
    @MainActor
    func loginWithTwitter() async {
        await login(with: .twitter)
    }
    
    // MARK: Reload user
    func reloadUser() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        do {
            try await currentUser.reload()
            self.user = UserAuthModel.fromFirebase(currentUser, providerId: currentUser.providerData.first?.providerID ?? "password")
            self.isEmailVerified = currentUser.isEmailVerified
        } catch {
            print("Error reloading user: \(error.localizedDescription)")
        }
    }

    // MARK: - Logout
    func logout() async {
        isLoading = true
        error = nil
        
        do {
            // Get UID before logout
            let uid = user?.uid
            
            try await authService.logout()
            self.user = nil
            
            // Clear pending registration data
            userDefaultsService.clearAllData()
            
            // Clear cached registration status for this user
            if let uid = uid {
                userDefaultsService.cacheRegistrationStatus(uid: uid, completed: false)
            }
            
        } catch {
            self.error = error.localizedDescription
            print("Logout error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Mark as Returning User (UPDATED)
    func markAsReturningUser() async {
        // Mark registration as completed locally
        userDefaultsService.markRegistrationCompleted()
        isFirstTimeUser = false
        print("✅ User marked as returning user")
    }
    
    // MARK: - Refresh User Status
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
            
            // Clear local data
            userDefaultsService.clearAllData()
            
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
