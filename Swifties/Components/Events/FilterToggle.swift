//
//  FilterToggle.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/09/25.
//

import SwiftUI

struct FilterToggle: View {
    @Binding var isMapView: Bool
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.orange)
                Text("Filter")
                    .foregroundColor(.orange)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
            
            HStack {
                Text("Map view")
                    .font(.system(size: 16, weight: .medium))
                
                Toggle("", isOn: $isMapView)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

