//
//  ProfileView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var authViewModel = AuthViewModel()
        
    var body: some View {
        
        ZStack{Color("appPrimary").ignoresSafeArea()
            VStack(spacing: 0) {
                // Custom Top Bar with notification button
                CustomTopBar(
                    title: "Profile",
                    showNotificationButton: true,
                    onBackTap:  {
                        print("Notifications tapped")
                    })
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Loading / Error / Content States
                        if viewModel.isLoading {
                            ProgressView("Loading profile…")
                                .padding(.top, 40)
                        } else if let error = viewModel.errorMessage {
                            VStack(spacing: 12) {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                Button("Retry") {
                                    viewModel.loadProfile()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.top, 40)
                        } else if let profile = viewModel.profile {
                            // Profile Header
                            ProfileHeader(
                                avatar_url: profile.profile.avatarURL,
                                name: profile.profile.name,
                                major: profile.profile.major,
                                age: profile.profile.age,
                                indoor_outdoor_score: profile.preferences.indoorOutdoorScore
                            )

                            // Preferences Section
                            PreferencesSection(preferences: profile.preferences.favoriteCategories)

                            // Divider
                            Divider()
                                .padding(.horizontal, 20)

                            // Action Buttons
                            VStack(spacing: 15) {
                                ActionButton(
                                    title: "Change your password",
                                    backgroundColor: Color("appBlue")
                                ) {
                                    // Handle password change
                                    print("Change password tapped")
                                }

                                ActionButton(
                                    title: "Change your profile information",
                                    backgroundColor: Color("appBlue")
                                ) {
                                    // Handle profile info change
                                    print("Change profile info tapped")
                                }

                                ActionButton(
                                    title: "Log Out",
                                    backgroundColor: Color("appRed")
                                ) {
                                    // Handle log out
                                    Task {
                                        await authViewModel.logout()
                                    }
                                }

                                ActionButton(
                                    title: "Delete your account",
                                    backgroundColor: Color("appRed")
                                ) {
                                    // Handle account deletion
                                    Task {
                                        await authViewModel.deleteAccount()
                                    }
                                }
                            }
                            .padding(.horizontal, 20)

                            // Bottom spacing for tab bar
                            Spacer()
                        } else {
                            // No profile available
                            Text("No profile data available.")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                            
                            Button("Reload") {
                                viewModel.loadProfile()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .background(Color("appPrimary"))
                .task { viewModel.loadProfile() }
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}


#Preview {
    ProfileView()
}
