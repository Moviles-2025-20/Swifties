//
//  CustomTabBar.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            TabBarButton(icon: "house", isSelected: selectedTab == 0) { selectedTab = 0 }
            Spacer()
            TabBarButton(icon: "lightbulb", isSelected: selectedTab == 1) { selectedTab = 1 }
            Spacer()
            TabBarButton(icon: "wand.and.sparkles", isSelected: selectedTab == 2) { selectedTab = 2 }
            Spacer()
            TabBarButton(icon: "person", isSelected: selectedTab == 3) { selectedTab = 3 }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: -2)
        )
    }
}
