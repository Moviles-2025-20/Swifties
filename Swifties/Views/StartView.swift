//
//  StartView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
//

import SwiftUI

struct StartView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea(.all)
            
            shapeView(size: 400,
                      color: Color("appOcher"))
            .offset(x: 200, y: 100)
            
            shapeView(size: 125,
                      color: Color("appRed"))
            .offset(x: -180, y: -225)
            
            VStack(spacing: 12) {
                Spacer()
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .accessibilityHidden(true)
                
                Text("Parchandes")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.appBlue)
                    .accessibilityLabel("Parchandes App")
                
                Spacer()
                
                HStack(spacing: 12) {
                    NavigationLink(destination: LoginView()
                        .environmentObject(authViewModel)) {
                        Text("Log In")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 45)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("appBlue"))
                    
                    Button {
                        print("Registering...")
                    } label: {
                        Text("Register")
                            .frame(width: 120, height: 45)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("appSecondary"))
                }
                
                Spacer()
                
            }
        }
    }
}

struct shapeView: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size)
    }
}

#Preview {
    StartView()
        .environmentObject(AuthViewModel())
}
