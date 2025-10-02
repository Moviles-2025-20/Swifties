//
//  ProfileView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI

struct ProfileView: View {
    @State private var selectedTab = 3 // Profile tab selected
    
    let preferences = ["Music", "Asian community", "Exchange", "Social activities", "Sports", "Art"]
    
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
                        // Profile Header
                        ProfileHeader(
                            imageName: "profile_image",
                            name: "Juliana Torres",
                            major: "Communications",
                            age: 21,
                            personality: "Extroverted"
                        )
                        
                        // Preferences Section
                        PreferencesSection(preferences: preferences)
                        
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
                    }
                }
                .background(Color("appPrimary"))
                
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
