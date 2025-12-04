//
//  MainView.swift
//  Swifties
//
//  Created by Imac on 2/10/25.
//

import SwiftUI

struct MainView: View {
    
    // MARK: - Properties
    @State private var selectedTab: Int = 0
    @State private var showNFCWriter: Bool = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // MARK: - Body
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                contentView(for: selectedTab)
                
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.all, edges: .bottom)
            
            // Floating NFC Writer Button (only show on Wish Me Luck tab)
            if selectedTab == 2 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showNFCWriter = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Above the tab bar
                    }
                }
            }
        }
        .sheet(isPresented: $showNFCWriter) {
            NFCTagWriterView()
        }
    }
    
    // MARK: - Private Views
    @ViewBuilder
    private func contentView(for tab: Int) -> some View {
        switch tab {
        case 0:
            HomeView()
        case 1:
            EventListView(viewModel: EventListViewModel())
        case 2:
            WishMeLuckView()
        case 3:
            ProfileView()
        default:
            HomeView()
        }
    }
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
