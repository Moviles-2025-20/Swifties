//
//  ProfileHeader.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

// Profile Header Component
struct ProfileHeader: View {
    let avatar_url: String?
    let name: String
    let major: String
    let age: Int
    let indoor_outdoor_score: String
    
    var body: some View {
        HStack(spacing: 20) {
            // Profile Image
            Group {
                if let avatar_url, let url = URL(string: avatar_url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 90, height: 90)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.gray)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray)
                }
            }
            .background(
                Circle()
                    .fill(Color.pink.opacity(0.3))
                    .frame(width: 90, height: 90)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Major - \(major)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Age - \(age)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Personality score - \(indoor_outdoor_score)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}
