//
//  TagChip.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct TagChip: View {
    let text: String
    let backgroundColor: Color
    
    init(_ text: String, backgroundColor: Color = Color("appOcher")) {
        self.text = text
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .cornerRadius(20)
    }
}
