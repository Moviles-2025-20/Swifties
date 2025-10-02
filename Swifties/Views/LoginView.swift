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
    @State private var shouldNavigate = false
    @State private var navigationDestination: NavigationDestination?
    
    enum NavigationDestination {
        case home
        case onboarding
    }
    
    // MARK: - Login with Google
    private func signInWithGoogle() {
        Task {
            await viewModel.loginWithGoogle()
        }
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationDestination(isPresented: $shouldNavigate) {
                if let destination = navigationDestination {
                    switch destination {
                    case .home:
                        HomeView()
                            .environmentObject(viewModel)
                            .navigationBarBackButtonHidden(true)
                    case .onboarding:
                        OnboardingView()
                            .environmentObject(viewModel)
                            .navigationBarBackButtonHidden(true)
                    }
                }
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
            CountdownView(onComplete: {
                handleImmediateNavigation()
            }).padding(.horizontal,40)
            
            Spacer()
        }
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
        // Auto-redirect happens in CountdownView after 3 seconds
    }
    
    private func handleImmediateNavigation() {
        if viewModel.isFirstTimeUser {
            print("Navigating to onboarding...")
            navigationDestination = .onboarding
        } else {
            print("Navigating to home...")
            navigationDestination = .home
        }
        shouldNavigate = true
    }
}

// MARK: - Countdown View
struct CountdownView: View {
    @State private var countdown = 3
    let onComplete: () -> Void
    
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
        .onReceive(
            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        ) { _ in
            if countdown > 0 {
                countdown -= 1
                if countdown == 0 {
                    onComplete()
                }
            }
        }
    }

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
