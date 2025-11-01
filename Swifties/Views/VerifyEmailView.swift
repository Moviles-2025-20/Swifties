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
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Floating connection status banner at the top
                if !networkMonitor.isConnected {
                    VStack {
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
                        .padding(.top, 8)
                    }
                }
                
                Spacer().frame(height: 40)

                Text("Verify your email")
                    .font(.title2).bold()
                    .foregroundColor(.appBlue)

                Text("We sent a verification link to your email. Please tap the link, then return to the app.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)

                // Status indicator
                HStack(spacing: 8) {
                    ProgressView().tint(.appRed)
                    Text("Waiting for verification…")
                        .foregroundColor(.secondary)
                }

                // Resend with cooldown
                ResendEmailButton()
                    .environmentObject(viewModel)
                    .padding(.horizontal, 20)
                    .disabled(!networkMonitor.isConnected)

                Button {
                    Task { await viewModel.logout() }
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
                    .disabled(!networkMonitor.isConnected)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
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

struct ResendEmailButton: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var cooldown: Int = 30
    @State private var canResend: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            Button {
                guard canResend else { return }
                Task { await viewModel.resendVerificationEmail() }
                startCooldown()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 24)

                    Text(canResend ? "Resend email" : "Resend in \(cooldown)s")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .foregroundColor(.black)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(canResend ? Color.appOcher : Color.gray.opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(!canResend)

            Text("Didn’t get the email? Check your spam folder.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func startCooldown() {
        canResend = false
        cooldown = 30
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if cooldown > 0 {
                cooldown -= 1
            } else {
                canResend = true
                timer.invalidate()
            }
        }
    }
}

#Preview {
    VerifyEmailView()
}
