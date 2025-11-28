import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import Network

struct WeeklyChallengeView: View {
    @StateObject private var viewModel = WeeklyChallengeViewModel()
    @Environment(\.dismiss) var dismiss
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    @State private var showNews: Bool = false

    // MARK: - Computed Properties for Data Source Indicator
    private var dataSourceIcon: String {
        switch viewModel.dataSource {
        case .memoryCache: return "memorychip"
        case .realmStorage: return "internaldrive"
        case .network: return "wifi"
        case .none: return "questionmark"
        }
    }
    
    private var dataSourceText: String {
        switch viewModel.dataSource {
        case .memoryCache: return "Memory Cache"
        case .realmStorage: return "Realm Storage"
        case .network: return "Updated from Network"
        case .none: return ""
        }
    }
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom top bar with back button
                CustomTopBar(title: "Weekly Challenge",
                             showNotificationButton: true,
                             showBackButton: true,
                             onNotificationTap: {
                    showNews = true
                },
                             onBackTap: {
                    dismiss()
                })
                
                // Connection status banner (placed before data source indicator)
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
                
                // Data Source Indicator (minimalist gray style like HomeView)
                if !viewModel.isLoading && viewModel.challengeEvent != nil {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Image(systemName: dataSourceIcon)
                                .foregroundColor(.secondary)
                            Text(dataSourceText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Updating...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // MARK: - Main Content Area
                if viewModel.isLoading {
                    // Loading state
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading challenge...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                } else if !networkMonitor.isConnected && viewModel.challengeEvent == nil {
                    // Offline state with no cached data
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Internet Connection")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("No cached or stored data available")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Text("Please connect to the internet and try again to load the weekly challenge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            if !networkMonitor.isConnected {
                                offlineAlertMessage = "Still no internet connection - Please check your network settings"
                                showOfflineAlert = true
                            } else {
                                viewModel.loadChallenge()
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
                                viewModel.loadChallenge()
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
                        VStack(spacing: 24) {
                            // Challenge Event Card
                            if let event = viewModel.challengeEvent {
                                VStack(spacing: 0) {
                                    // Event Image
                                    if let url = URL(string: event.metadata.imageUrl), !event.metadata.imageUrl.isEmpty {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Challenge Badge
                                        HStack {
                                            Image(systemName: "star.circle.fill")
                                                .foregroundColor(.yellow)
                                            Text("THIS WEEK'S CHALLENGE")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.orange)
                                            Spacer()
                                        }
                                        
                                        // Event Title
                                        Text(event.title)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        // Event Description
                                        Text(event.description)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                        
                                        // Event Details
                                        VStack(spacing: 8) {
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.orange)
                                                Text(event.schedule.days.joined(separator: ", "))
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text(event.schedule.times.first ?? "TBD")
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Image(systemName: "mappin.circle")
                                                    .foregroundColor(.red)
                                                Text(event.location?.address ?? "")
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        
                                        // Attend Button
                                        Button(action: {
                                            viewModel.markAsAttending()
                                        }) {
                                            HStack {
                                                Image(systemName: viewModel.hasAttended ? "checkmark.circle.fill" : "hand.raised.fill")
                                                Text(viewModel.hasAttended ? "Challenge Accepted!" : "I'm Going to Attend")
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(viewModel.hasAttended ? Color.green : Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                        .disabled(viewModel.hasAttended)
                                    }
                                    .padding()
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("No challenge available this week")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                            
                            // Stats Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Progress")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                // ... unchanged stats UI ...
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding()
                    }
                }
            }
        }
        .alert("Connection Required", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(offlineAlertMessage)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.debugCache()
                viewModel.loadChallenge()
            }
        }
        .navigationDestination(isPresented: $showNews) {
            NewsView()
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

extension Event: Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.name == rhs.name &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description
    }
}

