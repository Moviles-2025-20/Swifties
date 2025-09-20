//
//  LoginView.swift
//  SwiftiesApp
//
//  Created by Juan Esteban Vasquez Parra on 19/09/25.
//

import SwiftUI

struct LoginView: View {
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea(.all)
            
            VStack (spacing: 12){
                Spacer()
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 256, height: 256)
                    .accessibilityHidden(true)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Log In") {}
                    Button("Register") {}
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
