//
//  HomeView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var selectedTab = 0
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject var profileViewModel = ProfileViewModel()
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    
    // MARK: - Computed Properties for Data Source
    private var dataSourceIcon: String {
        switch homeViewModel.dataSource {
        case .memoryCache: return "memorychip"
        case .localStorage: return "internaldrive"
        case .network: return "wifi"
        case .none: return "questionmark"
        }
    }

    private var dataSourceText: String {
        switch homeViewModel.dataSource {
        case .memoryCache: return "Memory Cache"
        case .localStorage: return "Local Storage"
        case .network: return "Updated from Network"
        case .none: return ""
        }
    }
    
    private var dataSourceColor: Color {
        switch homeViewModel.dataSource {
        case .memoryCache: return .purple
        case .localStorage: return .blue
        case .network: return .green
        case .none: return .secondary
        }
    }
        
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                VStack {
                    
                    CustomTopBar(
                        title: "Hi, \(getUserFirstName())!",
                        showNotificationButton: true, onBackTap: {
                            print("Notifications tapped")
                        })
                    
                    // Data Source Indicator
                    if !homeViewModel.isLoading && !homeViewModel.recommendations.isEmpty {
                        HStack {
                            Image(systemName: dataSourceIcon)
                                .foregroundColor(dataSourceColor)
                            Text(dataSourceText)
                                .font(.caption)
                                .foregroundColor(dataSourceColor)
                            
                            if homeViewModel.isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Updating...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Debug button (optional, remove in production)
                            Button(action: {
                                homeViewModel.debugCache()
                            }) {
                                Image(systemName: "ladybug")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground).opacity(0.8))
                    }

                    ScrollView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("What's on your mind today?")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)
                                
                                Spacer()
                            }
                            .padding(.bottom, 10)
                            
                            HStack(spacing: 15) {
                                NavigationLink(destination: WeeklyChallengeView().navigationBarHidden(true)) {
                                    Text("Weekly Challenge")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appBlue"))
                                
                                NavigationLink(destination: UserInfoView().navigationBarHidden(true)) {
                                    Text("Events For Your Free Time")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appRed"))
                            }
                            .padding(.bottom, 10)
                            
                            HStack(spacing: 15) {
                                Button(action: {
                              
                                }) {
                                    Text("Coming soon...")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appRed"))

                                
                                Button {
                                    print("Future feature")
                                } label: {
                                    Text("Coming soon...")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appBlue"))
                            }
                            
                            HStack {
                                Text("Daily Recommendations")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)
                                
                                Spacer()
                            }
                            .padding(.top, 20)
                            
                            // MARK: - Recommendations Section with Improved Messages
                            VStack(spacing: 12) {
                                if homeViewModel.isLoading {
                                    // Loading state
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                        Text("Loading recommendations...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 60)
                                    
                                } else if !networkMonitor.isConnected && homeViewModel.recommendations.isEmpty {
                                    // Offline state with no cached data
                                    VStack(spacing: 20) {
                                        Image(systemName: "wifi.slash")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray.opacity(0.6))
                                            .accessibilityLabel("No internet connection")
                                        
                                        Text("No Internet Connection")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Text("No cached or stored data available")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 40)
                                        
                                        Text("Please connect to the internet and try again to load recommendations")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 40)
                                        
                                        Button(action: {
                                            if !networkMonitor.isConnected {
                                                offlineAlertMessage = "Still no internet connection - Please check your network settings"
                                                showOfflineAlert = true
                                            } else {
                                                Task {
                                                    await homeViewModel.getRecommendations()
                                                }
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Retry")
                                            }
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 12)
                                            .background(Color.gray.opacity(0.6))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                        }
                                        .padding(.top, 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 40)
                                    
                                } else if let error = homeViewModel.errorMessage {
                                    // Error state
                                    VStack(spacing: 20) {
                                        Image(systemName: getErrorIcon(for: error))
                                            .font(.system(size: 60))
                                            .foregroundColor(.red.opacity(0.8))
                                        
                                        Text("Something Went Wrong")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Text(error)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 40)
                                        
                                        Button(action: {
                                            if !networkMonitor.isConnected {
                                                offlineAlertMessage = "Cannot retry - No internet connection available"
                                                showOfflineAlert = true
                                            } else {
                                                Task {
                                                    await homeViewModel.getRecommendations()
                                                }
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Try Again")
                                            }
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                        }
                                        .padding(.top, 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 40)
                                    
                                } else if homeViewModel.recommendations.isEmpty {
                                    // Empty state (no error, just no data)
                                    VStack(spacing: 16) {
                                        Image(systemName: "star.slash")
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                        
                                        Text("No recommendations yet")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("We're working on finding the perfect events for you")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 24)
                                        
                                        if networkMonitor.isConnected {
                                            Button {
                                                Task {
                                                    await homeViewModel.forceRefresh()
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: "arrow.clockwise")
                                                    Text("Refresh")
                                                }
                                                .padding(.horizontal, 24)
                                                .padding(.vertical, 12)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(10)
                                            }
                                            .padding(.top, 8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    
                                } else {
                                    // Success state - show recommendations
                                    VStack(spacing: 12) {
                                        ForEach(homeViewModel.recommendations, id: \.title) { event in
                                            NavigationLink(destination: EventDetailView(event: event)) {
                                                EventInfo(
                                                    imagePath: event.metadata.imageUrl,
                                                    title: event.name,
                                                    titleColor: Color.orange,
                                                    description: event.description,
                                                    timeText: formatEventTime(event: event),
                                                    walkingMinutes: 5,
                                                    location: event.location?.address
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                    }
                }
                
                // Floating connection status banner (only when data is loaded)
                if !networkMonitor.isConnected && !homeViewModel.recommendations.isEmpty {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.orange)
                            Text("Offline - Using cached data")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 60)
                        
                        Spacer()
                    }
                }
            }
            .alert("Connection Required", isPresented: $showOfflineAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(offlineAlertMessage)
            }
        }
        .task {
            // Load profile data when view appears
            profileViewModel.loadProfile()
            
            // Debug and load recommendations
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                homeViewModel.debugCache()
                await homeViewModel.getRecommendations()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getUserFirstName() -> String {
        // Priority 1: Profile name from Firestore
        if let profileName = profileViewModel.profile?.profile.name, !profileName.isEmpty {
            let components = profileName.components(separatedBy: " ")
            return components.first ?? profileName
        }
        
        // Priority 2: Firebase Auth display name
        if let displayName = viewModel.user?.displayName, !displayName.isEmpty {
            let components = displayName.components(separatedBy: " ")
            return components.first ?? displayName
        }
        
        // Priority 3: Firebase Auth email (first part before @)
        if let email = viewModel.user?.email {
            let components = email.components(separatedBy: "@")
            return components.first ?? "User"
        }
        
        // Fallback
        return "User"
    }
    
    private func getErrorIcon(for error: String) -> String {
        if error.contains("network") || error.contains("connection") {
            return "wifi.slash"
        } else if error.contains("auth") || error.contains("user") {
            return "person.crop.circle.badge.exclamationmark"
        } else {
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Helper formatter function for including date
private func formatEventTime(event: Event) -> String {
    let day = event.schedule.days.first ?? ""
    let time = event.schedule.times.first ?? "Time TBD"
    
    if day.isEmpty {
        return time
    } else {
        return "\(day), \(time)"
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
