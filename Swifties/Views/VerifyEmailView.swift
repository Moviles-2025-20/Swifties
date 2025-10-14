//
//  VerifyEmailView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 3/10/25.
//

import SwiftUI
import Combine

struct VerifyEmailView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Please verify your email from the link sent to your inbox")
                
                Button {
                    Task {
                        await viewModel.resendVerificationEmail()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        
                        Text("Resend email")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(.appOcher)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                Button {
                    Task {
                        await viewModel.logout()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "eraser.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        
                        Text("Log out")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(.appRed)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
            }
        }
        .onReceive(Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await viewModel.reloadUser()
            }
        }
        .onChange(of: viewModel.isEmailVerified) { oldValue, newValue in
            if newValue {
                // When verification flips to true, the app root (SwiftiesApp) will update
                // and transition to MainView if gating is set there. If this view is in a
                // navigation stack, dismiss or navigate forward as needed.
            }
        }
    }
}

#Preview {
    VerifyEmailView()
}
