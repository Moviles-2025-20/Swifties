//
//  AuthService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 1/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit
import Combine

enum AuthenticationError: Error {
    case tokenError(message: String)
    case noRootViewController
    case clientIDNotFound
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .tokenError(let message):
            return "Token Error: \(message)"
        case .noRootViewController:
            return "No root view controller found"
        case .clientIDNotFound:
            return "Firebase client ID not found"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

class AuthService {
    // Singleton instance
    static let shared = AuthService()
    
    // Private initializer for singleton
    private init() {}
    
    // Auth state changes stream
    var authStateChanges: AsyncStream<User?> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user)
            }
            
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }
    
    // Current user
    var currentUser: User? {
        return Auth.auth().currentUser
    }
    
    // MARK: - Google Sign In
    func loginWithGoogle() async throws -> (user: User, providerId: String) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthenticationError.clientIDNotFound
        }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw AuthenticationError.noRootViewController
        }
        
        do {
            // Start Google sign-in
            let userAuthentication = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController
            )
            let user = userAuthentication.user
            
            guard let idToken = user.idToken else {
                throw AuthenticationError.tokenError(message: "ID token is missing")
            }
            
            let accessToken = user.accessToken
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken.tokenString,
                accessToken: accessToken.tokenString
            )
            
            // Authenticate with Firebase
            let result = try await Auth.auth().signIn(with: credential)
            let firebaseUser = result.user
            let providerId = credential.provider
            
            print("User \(firebaseUser.uid) signed in with email \(firebaseUser.email ?? "no email")")
            
            return (firebaseUser, providerId)
            
        } catch {
            print("Google Sign-In error: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Email Sign In
    func loginWithEmail(email: String, password: String) async throws -> (user: User, providerId: String) {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let firebaseUser = result.user
            let providerId = "password"
            print("User \(firebaseUser.uid) signed in")
            return (firebaseUser, providerId)
        } catch {
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Email Sign Up (Registration)
    func registerWithEmail(email: String, password: String) async throws -> (user: User, providerId: String) {
        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: AuthenticationError.unknown(error))
                    return
                }
                
                guard let user = result?.user else {
                    continuation.resume(throwing: AuthenticationError.tokenError(message: "No user after registration"))
                    return
                }
                
                // Send verification email
                user.sendEmailVerification { error in
                    if let error = error {
                        print("Failed to send verification email: \(error.localizedDescription)")
                    } else {
                        print("Verification email sent to \(email)")
                    }
                }
                
                continuation.resume(returning: (user, "password"))
            }
        }
    }
    func resendVerificationEmail() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthenticationError.tokenError(message: "No current user to send verification email")
        }
        try await user.sendEmailVerification()
    }
    

    // MARK: - Twitter Sign In
    func loginWithTwitter() async throws -> (user: User, providerId: String) {
        let provider = OAuthProvider(providerID: "twitter.com")
        
        return try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialWith(nil) { credential, error in
                if let error = error {
                    continuation.resume(throwing: AuthenticationError.unknown(error))
                    return
                }
                
                guard let credential = credential else {
                    continuation.resume(throwing: AuthenticationError.tokenError(message: "No Twitter credential"))
                    return
                }
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        continuation.resume(throwing: AuthenticationError.unknown(error))
                        return
                    }
                    
                    if let authResult = authResult {
                        let firebaseUser = authResult.user
                        let providerId = credential.provider
                        print("User \(firebaseUser.uid) signed in with Twitter")
                        continuation.resume(returning: (firebaseUser, providerId))
                    } else {
                        continuation.resume(throwing: AuthenticationError.tokenError(message: "No auth result from Twitter"))
                    }
                }
            }
        }
    }
    
    // MARK: - Password Reset
    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("Password reset email sent to \(email)")
        } catch {
            throw AuthenticationError.unknown(error)
        }
    }

    // MARK: - Logout
    func logout() async throws {
        do {
            if let providers = Auth.auth().currentUser?.providerData {
                for provider in providers {
                    if provider.providerID == "google.com" {
                        GIDSignIn.sharedInstance.signOut()
                        print("Google session signed out")
                    }
                    else if provider.providerID == "github.com" {
                        print("GitHub session cleared (handled by Firebase)")
                    }
                }
            }
            // Sign out from Firebase (clears all providers)
            try Auth.auth().signOut()
            print("User signed out successfully from Firebase")
        } catch {
            print("Sign out error: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }

    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthenticationError.tokenError(message: "No user to delete")
        }
        
        do {
            try await user.delete()
            print("User account deleted successfully")
        } catch {
            print("Delete account error: \(error.localizedDescription)")
            throw AuthenticationError.unknown(error)
        }
    }
}
