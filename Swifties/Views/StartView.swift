//
// StartView.swift
// Swifties
// Created by Natalia Villegas Calderón on 1/10/25.
//

import SwiftUI

struct StartView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showNoConnectionAlert = false
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea(.all)
            
            shapeView(size: 425,
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
                
                // Connection status indicator
                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                        Text("No Internet Connection")
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                HStack(spacing: 12) {
                    if networkMonitor.isConnected {
                        NavigationLink(destination: LoginView()
                            .environmentObject(authViewModel)) {
                            Text("Log In")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 45)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("appBlue"))
                    } else {
                        Button {
                            showNoConnectionAlert = true
                        } label: {
                            Text("Log In")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 45)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.gray)
                        // Remove .disabled(true) so the button can be tapped
                    }
                }
                
                Spacer()
            }
        }
        .alert("No Internet Connection", isPresented: $showNoConnectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your internet connection and try again.")
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
