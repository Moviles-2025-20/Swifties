//
//  MainView.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//
import SwiftUI

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            
        
            if !authViewModel.isAuthenticated {
                StartView()
            } else {
       
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    EventListView(viewModel: EventListViewModel())
                default:
                    HomeView()
                }
                
          
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

