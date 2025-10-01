//
//  SwiftiesApp.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 24/09/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct SwiftiesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var isLoading = true
    
    var body: some Scene {
        WindowGroup {
            if isLoading {
                LoadingView()
                    .onAppear {
                        // Cambiar a EventListView después de 2 segundos
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                isLoading = false
                            }
                        }
                    }
            } else {
                HomeView()
                //EventListView(viewModel: EventListViewModel())
            }
        }
    }
}
