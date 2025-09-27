//
//  CustomTopBar.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct CustomTopBar: View {
    let title: String
    let showNotificationButton: Bool
    let onNotificationTap: (() -> Void)?
    
    init(title: String, showNotificationButton: Bool = false, onNotificationTap: (() -> Void)? = nil) {
        self.title = title
        self.showNotificationButton = showNotificationButton
        self.onNotificationTap = onNotificationTap
    }
    
    var body: some View {
        ZStack {
            // Rounded background (bottom corners only)
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color("appBlue"))
                .ignoresSafeArea(edges: .top)
            
            // Centered title
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Notification button aligned to trailing
            HStack {
                Spacer()
                if showNotificationButton {
                    Button(action: { onNotificationTap?() }) {
                        Image(systemName: "bell")
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .frame(height: 50)
    }
}
