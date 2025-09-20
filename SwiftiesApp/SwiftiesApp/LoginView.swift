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
                    .frame(width: 128, height: 128)
                    .accessibilityHidden(true)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        print("Logging In...")
                    } label: {
                        Text("Log In")
                            .frame(width: 100, height:40)
                            .background(Color("appOchre"))
                            .font(.system(size: 15,
                                          weight: .semibold,
                                          design: .default))
                            .cornerRadius(10)
                            .foregroundStyle(.black)
                    }
                    Button {
                        print("Registering...")
                    } label: {
                        Text("Register")
                            .frame(width: 100, height:40)
                            .background(Color("appRed"))
                            .font(.system(size: 15,
                                          weight: .semibold,
                                          design: .default))
                            .cornerRadius(10)
                            .foregroundStyle(.black)
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
