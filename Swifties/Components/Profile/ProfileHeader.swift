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
    let indoor_outdoor_score: Int
    
    private var personalityLabel: String {
        if indoor_outdoor_score < 0 { return "Insider" }
        if indoor_outdoor_score > 0 { return "Outsider" }
        return "Neutral"
    }
    
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
                    .foregroundColor(.black)
                
                Text("Age - \(age)")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                Text("Personality: \(personalityLabel) (\(indoor_outdoor_score))")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                BipolarProgressBar(value: indoor_outdoor_score)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}

// MARK: - Bipolar progress bar (-100 to 100) starting at center
private struct BipolarProgressBar: View {
    let value: Int // expected range: -100...100
    var height: CGFloat = 8
    var negativeColor: Color = Color("appRed")
    var positiveColor: Color = Color("appBlue")
    
    var body: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            let floatValue = (CGFloat(value) / 100.0)
            let magnitude = min(max(abs(CGFloat(value)) / 100.0, 0), 1)
            let fillW = mid * magnitude
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height + 2)
                
                // Fill from center to the right for positive values
                if value > 0 {
                    Capsule()
                        .fill(positiveColor)
                        .frame(width: fillW, height: height)
                        .offset(x: mid)
                }
                
                // Fill from center to the left for negative values
                if value < 0 {
                    Capsule()
                        .fill(negativeColor)
                        .frame(width: fillW, height: height)
                        .offset(x: mid - fillW)
                }
                
                // Center tick
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: height, height: height)
                    .offset(x: mid * (1 + floatValue), y: height/2)
            }
        }
        .frame(height: height)
    }
}
