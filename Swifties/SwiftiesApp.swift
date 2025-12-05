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

        // Enable Firestore offline persistence with persistent cache
        let settings = FirestoreSettings()
        
        // Use persistent cache with unlimited size (recommended for offline support)
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited)
        )
        
        Firestore.firestore().settings = settings
        
        print("✅ Firestore offline persistence enabled with unlimited cache")

        // Test Firestore connection (only if online)
        let networkMonitor = NetworkMonitorService.shared
        if networkMonitor.isConnected {
            let db = Firestore.firestore(database: "default")
            db.collection("test").document("connection").setData(["test": "value"]) { error in
                if let error = error {
                    print("❌ Firestore connection failed: \(error.localizedDescription)")
                } else {
                    print("✅ Firestore connected successfully!")
                }
            }
        } else {
            print("!!!! Starting app in offline mode")
        }

        print("✅ Firebase Analytics initialized successfully")
        
        // Check for pending registration data and log status
        if UserDefaultsService.shared.hasPendingRegistration() {
            print("!!!! App started with pending registration data - will sync when connection available")
        }
        
        if UserDefaultsService.shared.hasCompletedRegistrationLocally() {
            print("ℹ️ User has completed registration locally")
        }
        
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
    @State private var deepLinkURL: URL?

    init() {
        NetworkMonitorService.shared.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                // Show loading while checking profile
                if authViewModel.isCheckingProfile {
                    VStack(spacing: 20) {
                        ProgressView("Loading...")
                            .tint(.appRed)
                        
                        // Show offline indicator if no connection
                        if !NetworkMonitorService.shared.isConnected {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("Offline Mode")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                } else if authViewModel.isAuthenticated, authViewModel.user != nil {
                    let isEmailProvider = (authViewModel.user?.providerId == "password")
                    let needsEmailVerification = isEmailProvider && (authViewModel.isEmailVerified == false)

                    if needsEmailVerification {
                        VerifyEmailView()
                            .environmentObject(authViewModel)
                    } else if authViewModel.isFirstTimeUser {
                        RegisterView()
                            .environmentObject(authViewModel)
                    } else {
                        MainView()
                            .environmentObject(authViewModel)
                            .onOpenURL{url in
                                handleDeepLink(url)
                            }
                    }
                } else {
                    StartView()
                        .environmentObject(authViewModel)
                }
            }
            .environmentObject(authViewModel)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("!!!!!!!!! Deep link received: \(url)")
        
        // Check if it's a scavenger hunt deep link
        guard url.scheme == "swifties",
              url.host == "scavenger" else {
            print("❌ Not a scavenger hunt link")
            return
        }
        
        print("✅ Scavenger hunt link detected!")
        deepLinkURL = url
        
        // Post notification to trigger navigation
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowNFCScavengerHunt"),
            object: url
        )
    }
}
