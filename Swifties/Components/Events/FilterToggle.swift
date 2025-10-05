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
        HStack(spacing: 12) {
            // Filter button/indicator
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.orange)
                Text("Filter")
                    .foregroundColor(.orange)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
            
            // Map/List toggle section
            HStack(spacing: 8) {
               
                Image(systemName: "list.dash")
                    .foregroundColor(isMapView ? .gray : .orange)
                    .font(.system(size: 16))
                
                Toggle("Map view toggle", isOn: $isMapView)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .scaleEffect(0.8)
                
                Image(systemName: "map")
                    .foregroundColor(isMapView ? .orange : .gray)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        FilterToggle(isMapView: .constant(false))
        FilterToggle(isMapView: .constant(true))
    }
}
