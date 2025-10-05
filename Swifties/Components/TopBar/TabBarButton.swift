//
//  TabBarButton.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct TabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color("appBlue")) // selected background
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                    
                    Image(systemName: icon)
                        .font(.system(size: 25))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(.black) // unselected color
                }
            }
            .frame(width: 60, height: 50) // makes all buttons equal size
        }
    }
}

