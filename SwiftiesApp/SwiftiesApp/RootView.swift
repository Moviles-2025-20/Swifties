//
//  RootView.swift
//  SwiftiesApp
//
//  Created by Juan Esteban Vasquez Parra on 19/09/25.
//

import SwiftUI

struct RootView: View {
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
            } else {
                ContentView()
            }
        }
        .task {
            // Simulate async work (e.g., configuration, network warmup)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeInOut) {
                isLoading = false
            }
        }
    }
}

