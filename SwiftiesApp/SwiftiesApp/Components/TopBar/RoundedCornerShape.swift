//
//  RoundedCornerShape.swift
//  SwiftiesApp
//
//  Created by NATALIA VILLEGAS CALDERON on 19/09/25.
//

import SwiftUI
import UIKit
struct RoundedCornerShape: Shape {
    var radius: CGFloat = 25.0
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    RoundedCornerShape(radius: 30, corners: [.topLeft, .bottomRight])
        .fill(Color.blue)
        .frame(width: 200, height: 100)
}
