//
//  BadgeCardView.swift
//  Swifties
//
//  Individual Badge Card Component
//

import SwiftUI
import FirebaseStorage

struct BadgeCardView: View {
    let badgeWithProgress: BadgeWithProgress
    @State private var iconURL: String?
    
    private var badge: Badge { badgeWithProgress.badge }
    private var userBadge: UserBadge { badgeWithProgress.userBadge }
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: rarityColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                if let iconURL = iconURL, let url = URL(string: iconURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                    } placeholder: {
                        ProgressView()
                    }
                    .opacity(userBadge.isUnlocked ? 1.0 : 0.3)
                } else {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .opacity(userBadge.isUnlocked ? 1.0 : 0.3)
                }
                
                // Lock overlay
                if !userBadge.isUnlocked {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Badge Info
            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(userBadge.isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(badge.rarity.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(badge.rarity.color).opacity(0.2))
                    .foregroundColor(Color(badge.rarity.color))
                    .cornerRadius(4)
            }
            
            // Progress Bar
            if !userBadge.isUnlocked {
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(badge.rarity.color))
                                .frame(width: geometry.size.width * CGFloat(badgeWithProgress.progressPercentage) / 100, height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(userBadge.progress) / \(badge.criteriaValue)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Unlocked")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }
            
            // Description
            Text(badge.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            loadIcon()
        }
    }
    
    private var rarityColors: [Color] {
        switch badge.rarity {
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
    
    private func loadIcon() {
        BadgeNetworkService.shared.resolveBadgeIconURL(iconPath: badge.icon) { url in
            DispatchQueue.main.async {
                self.iconURL = url
            }
        }
    }
}
