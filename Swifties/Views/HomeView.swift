//
//  HomeView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var selectedTab = 0
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject var profileViewModel = ProfileViewModel()
    @State private var recommended: [Event] = []
        
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack {
                    CustomTopBar(
                        title: "Hi, \(getUserFirstName())!",
                        showNotificationButton: true, onBackTap: {
                            print("Notifications tapped")
                        })

                    ScrollView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("What's on your mind today?")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)
                                
                                Spacer()
                            }
                            .padding(.bottom, 10)
                            
                            HStack(spacing: 15) {
                                NavigationLink(destination: WeeklyChallengeView().navigationBarHidden(true)) {
                                    Text("Weekly Challenge")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appBlue"))
                                
                                NavigationLink(destination: UserInfoView().navigationBarHidden(true)) {
                                    Text("Events For Your Free Time")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appRed"))
                            }
                            .padding(.bottom, 10)
                            
                            HStack(spacing: 15) {
                                Button(action: {
                              
                                }) {
                                    Text("Coming soon...")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appRed"))

                                
                                Button {
                                    print("Future feature")
                                } label: {
                                    Text("Coming soon...")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appBlue"))
                            }
                            
                            HStack {
                                Text("Daily Recommendations")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)
                                
                                Spacer()
                            }
                            .padding(.top, 20)
                            
                            VStack(spacing: 12) {
                                if recommended.isEmpty {
                                    ProgressView("Loading recommendations…")
                                } else {
                                    ForEach(recommended, id: \.title) { event in
                                        NavigationLink(destination: EventDetailView(event: event)) {
                                            EventInfo(
                                                imagePath: event.metadata.imageUrl,
                                                title: event.name,
                                                titleColor: Color.orange,
                                                description: event.description,
                                                timeText: formatEventTime(event: event),  // EDIT: Updated to include day
                                                walkingMinutes: 5,
                                                location: event.location?.address
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            // Load profile data when view appears
            profileViewModel.loadProfile()
            
            // Load recommendations
            await homeViewModel.getRecommendations()
            recommended = homeViewModel.recommendations
        }
    }
    
    // MARK: - Helper Function
    private func getUserFirstName() -> String {
        // Priority 1: Profile name from Firestore
        if let profileName = profileViewModel.profile?.profile.name, !profileName.isEmpty {
            let components = profileName.components(separatedBy: " ")
            return components.first ?? profileName
        }
        
        // Priority 2: Firebase Auth display name
        if let displayName = viewModel.user?.displayName, !displayName.isEmpty {
            let components = displayName.components(separatedBy: " ")
            return components.first ?? displayName
        }
        
        // Priority 3: Firebase Auth email (first part before @)
        if let email = viewModel.user?.email {
            let components = email.components(separatedBy: "@")
            return components.first ?? "User"
        }
        
        // Fallback
        return "User"
    }
}

// MARK: - Helper formater function for incluiding date
private func formatEventTime(event: Event) -> String {
    let day = event.schedule.days.first ?? ""
    let time = event.schedule.times.first ?? "Time TBD"
    
    if day.isEmpty {
        return time
    } else {
        return "\(day), \(time)"
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
