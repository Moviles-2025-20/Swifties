//
//  SwiftiesApp.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 24/09/25.
//

import SwiftUI
import FirebaseCore
import UserNotifications

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Inicializar Firebase
        FirebaseApp.configure()
        
        // Configurar notificaciones
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestAuthorization()
        
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - Main App
@main
struct SwiftiesApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    

    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
    
            MainView()
                .environmentObject(authViewModel)
        }
    }
}
