//
//  BadgeDetailView.swift
//  Swifties
//
//  Badge Detail Screen with Three-Layer Cache
//

import SwiftUI

struct BadgeDetailView: View {
    let badgeId: String
    let userId: String
    
    @StateObject private var viewModel: BadgeDetailViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    init(badgeId: String, userId: String) {
        self.badgeId = badgeId
        self.userId = userId
        _viewModel = StateObject(wrappedValue: BadgeDetailViewModel(badgeId: badgeId, userId: userId))
    }
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom top bar
                CustomTopBar(
                    title: "Badge Details",
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
                
                // Main Content
                if viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading badge details...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text("Error Loading Badge")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            viewModel.loadBadgeDetail()
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
                    
                } else if let detail = viewModel.badgeDetail {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Badge Icon Header
                            BadgeDetailHeaderView(detail: detail)
                            
                            // Progress Section
                            BadgeProgressSectionView(detail: detail)
                            
                            // Information Section
                            BadgeInfoSectionView(detail: detail)
                            
                            // Statistics Section
                            BadgeStatsSectionView(detail: detail)
                            
                            // Unlock Date (if unlocked)
                            if detail.userBadge.isUnlocked, let earnedAt = detail.userBadge.earnedAt {
                                UnlockDateView(date: earnedAt)
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadBadgeDetail()
        }
    }
}

// MARK: - Header View
struct BadgeDetailHeaderView: View {
    let detail: BadgeDetail
    @State private var iconURL: String?
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: rarityColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .shadow(color: Color(detail.badge.rarity.color).opacity(0.5), radius: 20)
                
                if let iconURL = iconURL, let url = URL(string: iconURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                    } placeholder: {
                        ProgressView()
                    }
                    .opacity(detail.userBadge.isUnlocked ? 1.0 : 0.3)
                } else {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .opacity(detail.userBadge.isUnlocked ? 1.0 : 0.3)
                }
                
                if !detail.userBadge.isUnlocked {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 160, height: 160)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                }
            }
            
            Text(detail.badge.name)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            
            Text(detail.badge.rarity.displayName)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(detail.badge.rarity.color).opacity(0.2))
                .foregroundColor(Color(detail.badge.rarity.color))
                .cornerRadius(20)
        }
        .padding()
        .onAppear {
            BadgeNetworkService.shared.resolveBadgeIconURL(iconPath: detail.badge.icon) { url in
                DispatchQueue.main.async {
                    self.iconURL = url
                }
            }
        }
    }
    
    private var rarityColors: [Color] {
        switch detail.badge.rarity {
        case .common:
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        case .rare:
            return [Color.blue.opacity(0.8), Color.blue.opacity(0.5)]
        case .epic:
            return [Color.purple.opacity(0.8), Color.purple.opacity(0.5)]
        case .legendary:
            return [Color.orange.opacity(0.9), Color.yellow.opacity(0.6)]
        }
    }
}

// MARK: - Progress Section
struct BadgeProgressSectionView: View {
    let detail: BadgeDetail
    
    var body: some View {
        VStack(spacing: 16) {
            if detail.userBadge.isUnlocked {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unlocked!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("You've earned this badge")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(16)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Text("Progress")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(detail.userBadge.progress) / \(detail.badge.criteriaValue)")
                            .font(.headline)
                            .foregroundColor(Color(detail.badge.rarity.color))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 24)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(detail.badge.rarity.color), Color(detail.badge.rarity.color).opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(detail.progressPercentage) / 100, height: 24)
                        }
                    }
                    .frame(height: 24)
                    
                    Text("\(detail.progressPercentage)% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Keep going! Only \(detail.badge.criteriaValue - detail.userBadge.progress) more to unlock")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 5)
            }
        }
    }
}

// MARK: - Info Section
struct BadgeInfoSectionView: View {
    let detail: BadgeDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(detail.badge.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "target", title: "Requirement", value: detail.badge.criteriaType.displayName)
                InfoRow(icon: "number", title: "Goal", value: "\(detail.badge.criteriaValue)")
                InfoRow(icon: "star.fill", title: "Rarity", value: detail.badge.rarity.displayName)
                
                if detail.badge.isSecret {
                    InfoRow(icon: "eye.slash.fill", title: "Type", value: "Secret Badge")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

// MARK: - Stats Section
struct BadgeStatsSectionView: View {
    let detail: BadgeDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title3)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                StatCard(
                    icon: "person.3.fill",
                    title: "Earned By",
                    value: "\(detail.totalUsersWithBadge)",
                    subtitle: "users"
                )
                
                StatCard(
                    icon: "chart.bar.fill",
                    title: "Completion",
                    value: "\(detail.completionRate)%",
                    subtitle: "rate"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

// MARK: - Unlock Date View
struct UnlockDateView: View {
    let date: Date
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 30))
                .foregroundColor(.blue)
            
            Text("Unlocked on")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(formattedDate)
                .font(.callout)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}
