//
//  RoundedCorner.swift
//  SwiftiesApp
//
//  Created by NATALIA VILLEGAS CALDERON on 19/09/25.
//

import SwiftUI

// Custom Rounded Corner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
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
