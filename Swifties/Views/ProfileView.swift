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
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    @State private var showNews: Bool = false
    
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
        ZStack{ Color("appPrimary").ignoresSafeArea()
            VStack(spacing: 0) {
                // Custom Top Bar with news button
                CustomTopBar(
                    title: "Profile",
                    showNotificationButton: true,
                    onNotificationTap: { showNews = true },
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
                        } else if !networkMonitor.isConnected && viewModel.profile == nil {
                            // Offline state with no cached data - similar to WeeklyChallengeView
                            VStack(spacing: 20) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 60))
                                    .foregroundColor(.orange)
                                
                                Text("No Internet Connection")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("No cached or stored data available")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Text("Please connect to the internet and try again to load your profile")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button(action: {
                                    if !networkMonitor.isConnected {
                                        offlineAlertMessage = "Still no internet connection - Please check your network settings"
                                        showOfflineAlert = true
                                    } else {
                                        viewModel.loadProfile()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Retry")
                                    }
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                            .padding(.top, 40)
                            
                        } else if let error = viewModel.errorMessage {
                            VStack(spacing: 12) {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                if !networkMonitor.isConnected {
                                    Text("You're offline. Unable to fetch fresh data from the network.")
                                        .foregroundColor(.secondary)
                                }
                                
                                Button(action: {
                                    if !networkMonitor.isConnected {
                                        offlineAlertMessage = "Cannot retry - No internet connection available"
                                        showOfflineAlert = true
                                    } else {
                                        viewModel.loadProfile()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Retry")
                                    }
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
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

                            // NEW: Badges Button
                            NavigationLink(destination: BadgesView()) {
                                HStack {
                                    Image(systemName: "rosette")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                        .frame(width: 40)
                                    
                                    Text("My Badges")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    // Optional: Show count of unlocked badges
                                    Text("View all")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            // Divider
                            Divider()
                                .padding(.horizontal, 20)

                            // Offline warning message for action buttons
                            if !networkMonitor.isConnected {
                                HStack(spacing: 8) {
                                    Image(systemName: "wifi.slash")
                                        .foregroundColor(.orange)
                                    Text("Actions disabled while offline")
                                        .font(.callout)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                            }

                            // Action Buttons with Offline Protection
                            VStack(spacing: 15) {
                                ActionButton(
                                    title: "Change your password",
                                    backgroundColor: Color("appBlue")
                                ) {
                                    if !networkMonitor.isConnected {
                                        offlineAlertMessage = "Cannot change password - No internet connection available"
                                        showOfflineAlert = true
                                    } else {
                                        // Handle password change
                                        print("Change password tapped")
                                    }
                                }
                                .opacity(networkMonitor.isConnected ? 1.0 : 0.5)

                                ActionButton(
                                    title: "Change your profile information",
                                    backgroundColor: Color("appBlue")
                                ) {
                                    if !networkMonitor.isConnected {
                                        offlineAlertMessage = "Cannot change profile - No internet connection available"
                                        showOfflineAlert = true
                                    } else {
                                        // Handle profile info change
                                        print("Change profile info tapped")
                                    }
                                }
                                .opacity(networkMonitor.isConnected ? 1.0 : 0.5)

                                ActionButton(
                                    title: "Log Out",
                                    backgroundColor: Color("appRed")
                                ) {
                                    if !networkMonitor.isConnected {
                                        offlineAlertMessage = "Cannot log out - No internet connection available"
                                        showOfflineAlert = true
                                    } else {
                                        // Handle log out
                                        Task {
                                            await authViewModel.logout()
                                        }
                                    }
                                }
                                .opacity(networkMonitor.isConnected ? 1.0 : 0.5)

                                ActionButton(
                                    title: "Delete your account",
                                    backgroundColor: Color("appRed")
                                ) {
                                    if !networkMonitor.isConnected {
                                        offlineAlertMessage = "Cannot delete account - No internet connection available"
                                        showOfflineAlert = true
                                    } else {
                                        // Handle account deletion
                                        Task {
                                            await authViewModel.deleteAccount()
                                        }
                                    }
                                }
                                .opacity(networkMonitor.isConnected ? 1.0 : 0.5)
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
        .alert("Connection Required", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(offlineAlertMessage)
        }
        .navigationDestination(isPresented: $showNews) {
            NewsView()
        }
    }
}


#Preview {
    ProfileView()
}

