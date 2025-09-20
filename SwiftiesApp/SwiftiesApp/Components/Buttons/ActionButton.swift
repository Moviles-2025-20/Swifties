//
//  ActionButton.swift
//  SwiftiesApp
//
//  Created by NATALIA VILLEGAS CALDERON on 19/09/25.
//

import SwiftUI

// Action Button Component
struct ActionButton: View {
    let title: String
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .cornerRadius(25)
        }
    }
}
