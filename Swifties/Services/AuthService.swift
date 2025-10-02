//
//  AuthService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 1/10/25.
//
//
//  AuthService.swift
//  Swifties
//
//  Created on 01/10/25.
//

//
//  AuthService.swift
//  Swifties
//
//  Created on 01/10/25.
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
    
    // MARK: - Logout
    func logout() async throws {
        do {
            // Sign out from Google if signed in
            GIDSignIn.sharedInstance.signOut()
            
            // Sign out from Firebase
            try Auth.auth().signOut()
            print("User signed out successfully")
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
