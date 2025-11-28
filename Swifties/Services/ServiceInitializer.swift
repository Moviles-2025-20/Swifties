//
//  ServiceInitializer.swift
//  Swifties
//
//  Initialize all services at app launch
//

import Foundation

class ServiceInitializer {
    static let shared = ServiceInitializer()
    
    private init() {}
    
    func initializeAllServices() {
        print("🚀 Initializing all services...")
        
        // Initialize Badge Detail Services
        _ = BadgeDetailCacheService.shared
        _ = BadgeDetailStorageService.shared
        _ = BadgeDetailNetworkService.shared
        
        // Initialize Badge List Services (if not already initialized)
        _ = BadgeCacheService.shared
        _ = BadgeStorageService.shared
        _ = BadgeNetworkService.shared
        
        // Initialize Network Monitor
        _ = NetworkMonitorService.shared
        
        print("✅ All services initialized successfully")
    }
}

// MARK: - Usage in AppDelegate or App struct
/*
 Add this to your App struct or AppDelegate:
 
 @main
 struct SwiftiesApp: App {
     init() {
         FirebaseApp.configure()
         ServiceInitializer.shared.initializeAllServices()
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
         }
     }
 }
 */
