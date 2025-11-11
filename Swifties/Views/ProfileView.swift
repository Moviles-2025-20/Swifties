//
//  ProfileView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    // MARK: - Data Source Indicator (matches HomeView)
    private var dataSourceIcon: String {
        switch viewModel.dataSource {
        case .memoryCache: return "memorychip"
        case .localStorage: return "internaldrive"
        case .network: return "wifi"
        case .none: return "questionmark"
        }
    }
    
    private var dataSourceText: String {
        switch viewModel.dataSource {
        case .memoryCache: return "Memory Cache"
        case .localStorage: return "Local Storage"
        case .network: return "Updated from Network"
        case .none: return ""
        }
    }
        
    var body: some View {
        
        ZStack{Color("appPrimary").ignoresSafeArea()
            VStack(spacing: 0) {
                // Custom Top Bar with notification button
                CustomTopBar(
                    title: "Profile",
                    showNotificationButton: true,
                    onBackTap:  {
                        print("Notifications tapped")
                    })
                
                // Connection status indicator
                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                        Text("No Internet Connection")
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                
                // If profile information is empty
                if !networkMonitor.isConnected, viewModel.dataSource == .none {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                        Text("Cannot load profile from cache")
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                
                // Data Source Indicator (matches other views)
                if !viewModel.isLoading, viewModel.profile != nil {
                    HStack {
                        Image(systemName: dataSourceIcon)
                            .foregroundColor(.secondary)
                        Text(dataSourceText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // Loading / Error / Content States
                        if viewModel.isLoading {
                            ProgressView("Loading profile…")
                                .padding(.top, 40)
                        } else if let error = viewModel.errorMessage {
                            VStack(spacing: 12) {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                if !networkMonitor.isConnected {
                                    Text("You're offline. Cannot load from network or local storage.")
                                        .foregroundColor(.secondary)
                                }
                                
                                Button("Retry") {
                                    viewModel.loadProfile()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Spacer()
                            }
                            .padding(.top, 40)
                        } else if let profile = viewModel.profile {
                            // Profile Header
                            ProfileHeader(
                                avatar_url: profile.profile.avatarURL,
                                name: profile.profile.name,
                                major: profile.profile.major,
                                age: profile.profile.age,
                                indoor_outdoor_score: profile.preferences.indoorOutdoorScore
                            )

                            // Preferences Section
                            PreferencesSection(preferences: profile.preferences.favoriteCategories)

                            // Divider
                            Divider()
                                .padding(.horizontal, 20)

                            // Action Buttons
                            VStack(spacing: 15) {
                                ActionButton(
                                    title: "Change your password",
                                    backgroundColor: Color("appBlue")
                                ) {
                                    // Handle password change
                                    print("Change password tapped")
                                }
                                .disabled(!networkMonitor.isConnected)

                                ActionButton(
                                    title: "Change your profile information",
                                    backgroundColor: Color("appBlue")
                                ) {
                                    // Handle profile info change
                                    print("Change profile info tapped")
                                }
                                .disabled(!networkMonitor.isConnected)

                                ActionButton(
                                    title: "Log Out",
                                    backgroundColor: Color("appRed")
                                ) {
                                    // Handle log out
                                    Task {
                                        await authViewModel.logout()
                                    }
                                }
                                .disabled(!networkMonitor.isConnected)

                                ActionButton(
                                    title: "Delete your account",
                                    backgroundColor: Color("appRed")
                                ) {
                                    // Handle account deletion
                                    Task {
                                        await authViewModel.deleteAccount()
                                    }
                                }
                                .disabled(!networkMonitor.isConnected)
                            }
                            .padding(.horizontal, 20)

                            // Bottom spacing for tab bar
                            Spacer()
                        } else {
                            // No profile available
                            Text("No profile data available.")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                            
                            Button("Reload") {
                                viewModel.loadProfile()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .background(Color("appPrimary"))
                .task {
                    viewModel.loadProfile()
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}


#Preview {
    ProfileView()
}
