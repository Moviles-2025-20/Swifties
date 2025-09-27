//
//  ProfileHeader.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

// Profile Header Component
struct ProfileHeader: View {
    let imageName: String
    let name: String
    let major: String
    let age: Int
    let personality: String
    
    var body: some View {
        HStack(spacing: 20) {
            // Profile Image
            Image(systemName: "person.circle.fill") // Replace with actual image
                .font(.system(size: 80))
                .foregroundColor(.gray)
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

