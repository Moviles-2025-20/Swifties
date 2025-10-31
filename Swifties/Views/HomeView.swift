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
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
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
                    
                    // Data Source Indicator
                    if !homeViewModel.isLoading && !homeViewModel.recommendations.isEmpty {
                        HStack {
                            Image(systemName: dataSourceIcon)
                                .foregroundColor(.secondary)
                            Text(dataSourceText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if homeViewModel.isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Updating...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
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
                            
                            // Recommendations Section
                            if homeViewModel.isLoading {
                                ProgressView("Loading recommendations…")
                                    .padding(.vertical, 40)
                            } else if let error = homeViewModel.errorMessage {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text(error)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                    Button("Retry") {
                                        Task {
                                            await homeViewModel.getRecommendations()
                                        }
                                    }
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else if homeViewModel.recommendations.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "star.slash")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("No recommendations available")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
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
                            
                            Spacer(minLength: 80)
                        }
                    }
                }
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
    
    // MARK: - Helper Function
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
