//
//  ScreensCyclerView.swift
//  SwiftiesApp
//
//  Created by Assistant on 20/09/25.
//

import SwiftUI

/// A utility view that cycles through a list of screens each time the user taps anywhere.
struct ScreensCyclerView: View {
    private let screens: [AnyView]
    @State private var index: Int = 0

    init(screens: [AnyView]) {
        precondition(!screens.isEmpty, "ScreensCyclerView requires at least one screen")
        self.screens = screens
    }

    var body: some View {
        ZStack {
            // Current screen fills the space
            screens[safe: index] ?? screens.first!
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                index = (index + 1) % screens.count
            }
        }
    }
}

// MARK: - Helpers
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

// MARK: - Factory for default app screens
extension ScreensCyclerView {
    /// Builds a default ordered list of screens in your app for cycling.
    /// Edit this list to include all views under your Screens folder.
    static func defaultScreens() -> [AnyView] {
        var result: [AnyView] = []

        // Attempt to include NotificationsView if available
        #if canImport(SwiftUI)
        if isTypeAvailable("NotificationsView") {
            result.append(AnyView(NotificationsView()))
        }
        #endif

        // Include your main ContentView as a fallback/default.
        result.append(AnyView(ContentView()))

        // TODO: Add other screens here in the desired order, e.g.:
        // result.append(AnyView(ProfileView()))
        // result.append(AnyView(SettingsView()))

        return result
    }

    #if canImport(SwiftUI)
    /// Helper to check if a type exists at runtime (best effort)
    private static func isTypeAvailable(_ typeName: String) -> Bool {
        return NSClassFromString(typeName) != nil
    }
    #endif
}

// MARK: - Preview
#Preview {
    ScreensCyclerView(screens: [
        AnyView(DetailEvent()),
        AnyView(HomeView()),
        AnyView(NotificationsView()),
        AnyView(ProfileView()),
        AnyView(LoadingView()),
        AnyView(LoginView())
    ])
}
