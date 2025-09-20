//
//  LoadingView.swift
//  SwiftiesApp
//
//  Created by Juan Esteban Vasquez Parra on 19/09/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea(edges: .all)
            
            VStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 256, height: 256)
                    .accessibilityHidden(true)
                
                Text("Parchandes")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Parchandes App")
            }
            .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    LoadingView()
}
