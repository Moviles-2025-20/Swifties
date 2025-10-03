//
//  MainView.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//
import SwiftUI
struct MainView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            
            switch selectedTab {
            case 0:
                HomeView()
            case 1:
                EventListView(viewModel: EventListViewModel())
            case 3:
                ProfileView()
            default:
                HomeView()
            }
            
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}
