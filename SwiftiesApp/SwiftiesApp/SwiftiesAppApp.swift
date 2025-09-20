//
//  SwiftiesAppApp.swift
//  SwiftiesApp
//
//  Created by NATALIA VILLEGAS CALDERON on 14/09/25.
//

import SwiftUI

@main
struct SwiftiesAppApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("--cycleScreens") || ProcessInfo.processInfo.environment["CYCLE_SCREENS"] == "1" {
                ScreensCyclerView(screens: [
                    AnyView(DetailEvent()),
                    AnyView(HomeView()),
                    AnyView(NotificationsView()),
                    AnyView(ProfileView()),
                    AnyView(LoginView()),
                    AnyView(LoadingView()),
                ])
            } else {
                ContentView()
            }
        }
    }
}
