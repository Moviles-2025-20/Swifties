//
//  NewsView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 24/11/25.
//

import SwiftUI
import FirebaseAuth

struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    
    // MARK: - Computed Properties for Data Source Indicator
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
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Top Bar with back button - ensure full width
                CustomTopBar(
                    title: "News Feed",
                    showNotificationButton: false,
                    showBackButton: true,
                    onNotificationTap: nil,
                    onBackTap: { dismiss() }
                )
                .frame(maxWidth: .infinity) // fill available width
                
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
                if !viewModel.isLoading, !viewModel.news.isEmpty {
                    HStack {
                        Image(systemName: dataSourceIcon)
                            .foregroundColor(.secondary)
                        Text(dataSourceText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if viewModel.isRefreshing {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Updating...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                VStack(spacing: 12) {
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading news feed...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if !networkMonitor.isConnected && viewModel.news.isEmpty {
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
                                
                            Text("Please connect to the internet and try again")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                
                            Button(action: {
                                if !networkMonitor.isConnected {
                                    offlineAlertMessage = "Still no internet connection - Please check your network settings"
                                    showOfflineAlert = true
                                } else {
                                    viewModel.loadNews()
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
                        Spacer()
                        VStack(spacing: 20) {
                            Text("Something went wrong")
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
                                    viewModel.loadNews()
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
                        // Success state
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("News Feed")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                
                                if viewModel.news.isEmpty {
                                    Text("No news found")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    // Apply one horizontal padding here to keep cards within screen
                                    VStack(spacing: 12) {
                                        ForEach(viewModel.news, id: \.id) { item in
                                            CompactNewsCard(
                                                news: item,
                                                isLiked: isLiked(item),
                                                onToggleLike: { viewModel.toggleLike(item) }
                                            )
                                            .frame(maxWidth: .infinity) // card fills available width
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            Spacer(minLength: 80)
                        }
                        .background(Color("appPrimary"))
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadNews()
        }
        .alert("No Internet Connection", isPresented: $showOfflineAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(offlineAlertMessage)
        }
        // Hide default iOS back button and navigation bar style
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func isLiked(_ item: News) -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return item.ratings.contains(uid)
    }
}

// MARK: - Compact News Card (sized similarly to EventInfo)
private struct CompactNewsCard: View {
    let news: News
    let isLiked: Bool
    let onToggleLike: () -> Void
    
    // Tuned constants to keep a compact layout
    private let cornerRadius: CGFloat = 12
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top image (height-restricted)
            if let url = URL(string: news.photoUrl), !news.photoUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Loading placeholder
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    case .success(let image):
                        image
                            .resizable()
                    case .failure:
                        // Error placeholder
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            
            // Description + like row (compact)
            VStack(alignment: .leading, spacing: 8) {
                Text(news.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                HStack {
                    Spacer()
                    Button(action: onToggleLike) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                            .font(.system(size: 20, weight: .semibold))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}
