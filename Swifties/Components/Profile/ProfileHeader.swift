//
//  ProfileHeader.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

// Profile Header Component
struct ProfileHeader: View {
    let imageURL: String?
    let name: String
    let major: String
    let age: Int
    let personality: String
    
    var body: some View {
        HStack(spacing: 20) {
            // Profile Image
            Group {
                if let imageURL, let url = URL(string: imageURL) {
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
                
                Text("Personality - \(personality)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}
