//
//  UserInfoView.swift
//  Swifties
//
//  Created by
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserInfoView: View {
    @StateObject private var viewModel = UserInfoViewModel()
    @Environment(\.dismiss) var dismiss
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    
    // MARK: - Computed Properties for Data Source
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
    
    private var dataSourceColor: Color {
        switch viewModel.dataSource {
        case .memoryCache: return .purple
        case .localStorage: return .blue
        case .network: return .green
        case .none: return .secondary
        }
    }
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomTopBar(title: "Available Events",
                             showNotificationButton: true,
                             showBackButton: true,
                             onNotificationTap: {
                    print("Notification tapped")
                },
                             onBackTap: {
                    dismiss()
                })
                
                // Data Source Indicator
                if !viewModel.isLoading && !viewModel.availableEvents.isEmpty {
                    HStack {
                        Image(systemName: dataSourceIcon)
                            .foregroundColor(dataSourceColor)
                        Text(dataSourceText)
                            .font(.caption)
                            .foregroundColor(dataSourceColor)
                        
                        if viewModel.isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Updating...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Debug button (optional, remove in production)
                        Button(action: {
                            viewModel.debugCache()
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
                
                // MARK: - Main Content Area
                if viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your available events...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                } else if !networkMonitor.isConnected && viewModel.availableEvents.isEmpty && viewModel.freeTimeSlots.isEmpty {
                    // Offline state with no cached data
                    Spacer()
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
                        
                        Text("Please connect to the internet and try again to load your available events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            if !networkMonitor.isConnected {
                                offlineAlertMessage = "Still no internet connection - Please check your network settings"
                                showOfflineAlert = true
                            } else {
                                viewModel.loadData()
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
                    Spacer()
                    
                } else if let error = viewModel.errorMessage {
                    // Error state
                    Spacer()
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
                                viewModel.loadData()
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
                    Spacer()
                    
                } else {
                    // Success state - show content
                    ScrollView {
                        VStack(spacing: 20) {
                            // Free Time Slots Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Free Time")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                if viewModel.freeTimeSlots.isEmpty {
                                    Text("No free time slots configured")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.freeTimeSlots) { slot in
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.orange)
                                                Text(slot.day)
                                                    .fontWeight(.semibold)
                                                Spacer()
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text("\(slot.start) - \(slot.end)")
                                                    .font(.subheadline)
                                            }
                                            .padding()
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Available Events Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Events That Fit Your Schedule")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(viewModel.availableEvents.count)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal)
                                
                                if viewModel.availableEvents.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                        Text("No events match your free time")
                                            .foregroundColor(.secondary)
                                        Text("Try adjusting your availability or check back later")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(viewModel.availableEvents, id: \.title) { event in
                                            NavigationLink(destination: EventDetailView(event: event)) {
                                                EventInfo(
                                                    imagePath: event.metadata.imageUrl,
                                                    title: event.name,
                                                    titleColor: Color.green,
                                                    description: event.description,
                                                    timeText: formatEventTime(event: event),
                                                    walkingMinutes: 5,
                                                    location: event.location?.address
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            
            // Floating connection status banner at the top
            if !networkMonitor.isConnected && (!viewModel.availableEvents.isEmpty || !viewModel.freeTimeSlots.isEmpty) {
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
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.debugCache()
                viewModel.loadData()
            }
        }
    }
    
    // MARK: - Helper Functions
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

// MARK: - Preview
struct UserInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UserInfoView()
        }
    }
}
