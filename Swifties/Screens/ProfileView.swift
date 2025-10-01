//
//  ProfileView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedTab = 3 // Profile tab selected
    
    var body: some View {
        
        ZStack{Color("appPrimary").ignoresSafeArea()
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomTopBar(title: "Profile", showNotificationButton: true) {
                    // Handle notification tap
                    print("Notification tapped")
                }
                
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
                                imageURL: profile.imageURL,
                                name: profile.name,
                                major: profile.major,
                                age: profile.age,
                                personality: profile.personality
                            )

                            // Preferences Section
                            PreferencesSection(preferences: profile.preferences)

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
                                    print("Log out tapped")
                                }

                                ActionButton(
                                    title: "Delete your account",
                                    backgroundColor: Color("appRed")
                                ) {
                                    // Handle account deletion
                                    print("Delete account tapped")
                                }
                            }
                            .padding(.horizontal, 20)

                            // Bottom spacing for tab bar
                            Spacer(minLength: 80)
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
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}


#Preview {
    ProfileView()
}
