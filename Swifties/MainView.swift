//
//  MainView.swift
//  Swifties
//
//  Created by Imac on 2/10/25.
//

import SwiftUI

struct MainView: View {
    
    // MARK: - Properties
    @State private var selectedTab: Int = -1
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            contentView(for: selectedTab)
            
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    // MARK: - Private Views
    @ViewBuilder
    private func contentView(for tab: Int) -> some View {
        switch tab {
        case 0:
            HomeView()
        case 1:
            EventListView(viewModel: EventListViewModel())
        default:
            StartView()
        }
    }
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
