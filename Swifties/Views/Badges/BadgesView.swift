//
//  BadgesView.swift
//  Swifties
//
//  Main Badges Screen
//

import SwiftUI

struct BadgesView: View {
    @StateObject private var viewModel = BadgesViewModel()
    @Environment(\.dismiss) var dismiss
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    @State private var selectedFilter: BadgeFilter = .all
    
    enum BadgeFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case locked = "Locked"
    }
    
    private var filteredBadges: [BadgeWithProgress] {
        switch selectedFilter {
        case .all:
            return viewModel.badgesWithProgress
        case .unlocked:
            return viewModel.unlockedBadges
        case .locked:
            return viewModel.lockedBadges
        }
    }
    



    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom top bar
                CustomTopBar(
                    title: "My Badges",
                    showNotificationButton: false,
                    showBackButton: true,
                    onNotificationTap: {},
                    onBackTap: { dismiss() }
                )
                
                // Connection status banner
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
                
                
                // MARK: - Main Content
                if viewModel.isLoading {
                    // Loading state
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading badges...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                } else if !networkMonitor.isConnected && viewModel.badgesWithProgress.isEmpty {
                    // Offline state with no cached data
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Internet Connection")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("No cached data available")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            if !networkMonitor.isConnected {
                                offlineAlertMessage = "Still no internet connection"
                                showOfflineAlert = true
                            } else {
                                viewModel.loadBadges()
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
                    }
                    Spacer()
                    
                } else if let error = viewModel.errorMessage {
                    // Error state
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text("Something Went Wrong")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            viewModel.loadBadges()
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
                    }
                    Spacer()
                    
                } else {
                    // Success state
                    ScrollView {
                        VStack(spacing: 24) {
                            // Stats Header
                            VStack(spacing: 12) {
                                Text("\(viewModel.unlockedCount) / \(viewModel.totalBadges)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.orange)
                                
                                Text("Badges Unlocked")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                
                                // Progress Bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 20)
                                        
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(LinearGradient(
                                                colors: [.orange, .yellow],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(width: geometry.size.width * CGFloat(viewModel.completionPercentage) / 100, height: 20)
                                    }
                                }
                                .frame(height: 20)
                                .padding(.horizontal)
                                
                                Text("\(viewModel.completionPercentage)% Complete")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 5)
                            
                            // Filter Picker
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(BadgeFilter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            
                            // Badges Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(filteredBadges) { badgeWithProgress in
                                    BadgeCardView(badgeWithProgress: badgeWithProgress)
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Connection Required", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(offlineAlertMessage)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.debugCache()
                viewModel.loadBadges()
            }
        }
    }
}

#Preview {
    BadgesView()
}
