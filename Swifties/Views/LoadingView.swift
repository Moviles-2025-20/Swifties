//
//  LoadingView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
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
                    .frame(width: 384, height: 384)
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
