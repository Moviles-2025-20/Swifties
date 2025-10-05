//
//  PreferencesSection.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct PreferencesSection: View {
    let preferences: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("My preferences")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button("Browse More") {
                    // Handle browse more action
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.gray)
                .cornerRadius(20)
            }
            .padding(.horizontal, 20)
            
            // Tags
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(preferences, id: \.self) { preference in
                    TagChip(preference)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
