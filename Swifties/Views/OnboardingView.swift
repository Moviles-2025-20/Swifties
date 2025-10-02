//
//  OnboardingView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 1/10/25.
//



import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var selectedCategories: [String] = []
    @State private var indoorOutdoorScore: Int = 50
    @State private var isSubmitting = false
    @State private var navigateToHome = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Complete Your Profile")
                    .font(.system(size: 28, weight: .bold))
                
                // Your onboarding questions here
                // ... (category selection, indoor/outdoor slider, etc.)
                
                Spacer()
                
                Button {
                    saveUserData()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Complete Setup")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.appRed)
                .cornerRadius(12)
                .disabled(isSubmitting)
            }
            .padding()
            .navigationDestination(isPresented: $navigateToHome) {
                HomeView() // Your home view
            }
        }
    }
    
    private func saveUserData() {
        isSubmitting = true
        
        Task {
            do {
                // Create preferences from onboarding data
                let preferences = Preferences(
                    indoorOutdoorScore: indoorOutdoorScore,
                    favoriteCategories: selectedCategories,
                    completedCategories: [],
                    notifications: Notifications(freeTimeSlots: [])
                )
                
                // Save to Firestore
                //try await viewModel.createUserDocument(preferences: preferences)
                
                // Navigate to home
                navigateToHome = true
                
            } catch {
                print("Error saving user data: \(error.localizedDescription)")
                viewModel.error = "Failed to save profile. Please try again."
            }
            
            isSubmitting = false
        }
    }
}




