//
//  LoginView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 1/10/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var hasRedirected = false
    
    // MARK: - Login with Google
    private func signInWithGoogle() {
        Task {
            await viewModel.loginWithGoogle()
        }
    }
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            if viewModel.isAuthenticated {
                authenticatedView
            } else {
                loginView
            }
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuth in
            if isAuth {
                handleRedirect()
            }
        }
    }
    
    // MARK: - Login View
    private var loginView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            
            Text("Choose your login method")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.black.opacity(0.7))
            
            Spacer().frame(height: 40)
            
            // Google Login Button
            Button(action: signInWithGoogle) {
                HStack(spacing: 12) {
                    // Use SF Symbol as fallback if image doesn't load
                    Group {
                        if let _ = UIImage(named: "Google") {
                            Image("Google")
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 24))
                        }
                    }
                    
                    Text("Login with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(.appRed)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // GitHub Login Button (disabled)
            Button(action: {}) {
                HStack(spacing: 12) {
                    Group {
                        if let _ = UIImage(named: "GitHub") {
                            Image("GitHub")
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 20))
                        }
                    }
                    
                    Text("Login with GitHub")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .cornerRadius(12)
            }
            .disabled(true)
            .opacity(0.5)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Facebook Login Button (disabled)
            Button(action: {}) {
                HStack(spacing: 12) {
                    Group {
                        if let _ = UIImage(named: "Facebook") {
                            Image("Facebook")
                                .resizable()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "f.circle.fill")
                                .font(.system(size: 24))
                        }
                    }
                    
                    Text("Login with Facebook")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(.appBlue)
                .cornerRadius(12)
            }
            .disabled(true)
            .opacity(0.5)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Spacer().frame(height: 30)
            
            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .tint(.appRed)
            }
            
            // Error message
            if let error = viewModel.error {
                errorView(message: error)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Authenticated View
    private var authenticatedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Profile picture
            if let photoURL = viewModel.user?.photoURL,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.appRed, lineWidth: 3)
                )
            } else {
                Circle()
                    .fill(.appRed)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    )
            }
            
            Text("Welcome!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.appRed)
            
            Text(viewModel.user?.displayName ?? "User")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.black.opacity(0.87))
            
            Text(viewModel.user?.email ?? "")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            // Countdown progress
            CountdownView()
            
            Spacer().frame(height: 30)
            
            Button {
                handleImmediateNavigation()
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.appRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Views
    private func errorView(message: String) -> some View {
        HStack {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Navigation Handlers
    private func handleRedirect() {
        guard !hasRedirected else { return }
        hasRedirected = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            handleImmediateNavigation()
        }
    }
    
    private func handleImmediateNavigation() {
        if viewModel.isFirstTimeUser {
            print("Navigating to onboarding...")
            // TODO: NavigationStack or coordinator pattern
        } else {
            print("Navigating to home...")
            // TODO: NavigationStack or coordinator pattern
        }
    }
}

// MARK: - Countdown View
struct CountdownView: View {
    @State private var countdown = 3
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Redirecting in \(countdown) seconds...")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .italic()
            
            ProgressView(value: Double(3 - countdown), total: 3)
                .tint(.appRed)
                .frame(height: 4)
        }
        .onAppear {
            startCountdown()
        }
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
