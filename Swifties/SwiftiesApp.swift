//
//  SwiftiesApp.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 24/09/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)

        // Test Firestore connection
        let db = Firestore.firestore(database: "default")
        db.collection("test").document("connection").setData(["test": "value"]) { error in
            if let error = error {
                print("❌ Firestore connection failed: \(error.localizedDescription)")
            } else {
                print("✅ Firestore connected successfully!")
            }
        }

        print("✅ Firebase Analytics initialized successfully")
        return true
    }

    // Restrict the app to portrait mode only
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct SwiftiesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            // Use the authentication state as the key to force view refresh
            Group {
                if authViewModel.isAuthenticated && authViewModel.user != nil {
                    let needsEmailVerification = (authViewModel.user?.providerId == "password") && (authViewModel.isEmailVerified == false)
                    if needsEmailVerification {
                        NavigationStack {
                            VerifyEmailView()
                                .environmentObject(authViewModel)
                        }
                    } else {
                        NavigationStack {
                            MainView()
                                .environmentObject(authViewModel)
                        }
                    }
                } else {
                    NavigationStack {
                        StartView()
                            .environmentObject(authViewModel)
                    }
                }
            }
            .id(authViewModel.isAuthenticated) // Force view recreation on auth state change
            .environmentObject(authViewModel)
        }
    }
}
