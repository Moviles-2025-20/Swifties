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
    @State private var recommended: [Event]  = []
        
    var body: some View {
        NavigationStack { 
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack {
                    CustomTopBar(
                        title: "Hi, \(getUserFirstName())!",
                        showNotificationButton: true, onBackTap:  {
                            print("Notifications tapped")
                        })
                    
                    ScrollView {
                        VStack (spacing: 0) {
                            HStack {
                                Text("What's on your mind today?")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)
                                
                                Spacer()
                            }
                            .padding(.bottom, 10)
                            
                            HStack (spacing: 15) {
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
                            
                            HStack (spacing: 15) {
                                Button(action: {
                              
                                }) {
                                    Text("Coming soon")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appRed"))

                                
                                Button {
                                    print("Future Feature")
                                } label: {
                                    Text("Map")
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
                                                timeText: event.schedule.times.first ?? "Time TBD",
                                                walkingMinutes: 5,
                                                location: event.location?.address
                                            )
                                        }
                                }
                                .padding(.horizontal, 16)}
                            }
                            .task {
                                await homeViewModel.getRecommendations()
                                recommended = homeViewModel.recommendations
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Function
    private func getUserFirstName() -> String {
        let displayName = viewModel.user?.displayName ?? profileViewModel.profile?.profile.name ?? "User"
        
        let components = displayName.components(separatedBy: " ")
        return components.first ?? displayName
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
