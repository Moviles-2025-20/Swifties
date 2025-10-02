//
//  LoginView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.

import SwiftUI

struct LoginView: View {
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea(.all)
            
            shapeView(size: 400,
                      color:Color("appOcher"))
            .offset(x: 200, y: 100)
            
            shapeView(size: 125,
                      color: Color("appRed"))
            .offset(x: -180, y: -225)
            
            VStack (spacing: 12){
                Spacer()
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 256, height: 256)
                    .accessibilityHidden(true)
                
                Text("Parchandes")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Parchandes App")
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        print("Logging In...")
                    } label: {
                        Text("Log In")
                            .frame(width: 120, height: 45)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
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
                
                Button {
                    print("Skipping login for now...")
                } label: {
                    Text("Skip it for now")
                        .font(.title3.weight(.semibold))
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
    LoginView()
}
