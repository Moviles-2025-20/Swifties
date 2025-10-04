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
                                    // No hacer nada
                                }) {
                                    Text("Wish me Luck")
                                        .frame(width: 120, height: 80)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color("appRed"))

                                
                                Button {
                                    print("Map")
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
                                Text("Daily Recommendation")
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
                                    ForEach(recommended) { event in
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
                                do {
                                    recommended = try await homeViewModel.getRecommendations()
                                } catch {
                                    print("Error loading recommendations: \(error)")
                                }
                            }
                            
                            EventInfo(imagePath: "evento",
                                      title: "Daily Marathon",
                                      titleColor: Color("appOcher"),
                                      description: "Have a blast with us on our daily marathon!",
                                      timeText: "Today, 10am",
                                      walkingMinutes: 8,
                                      location: "Lleras"
                            ).padding(.horizontal, 16)
                            
                            HStack {
                                Text("Close to you")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)
                                
                                Spacer()
                            }
                            .padding(.top, 20)
                            
                            EventInfo(imagePath: "evento",
                                      title: "Cívico Pets",
                                      titleColor: Color("appOcher"),
                                      description: "Bring your pets to the Civic Center",
                                      timeText: "Tomorrow, 8-10am",
                                      walkingMinutes: 4,
                                      location: "RGD")
                            .padding(.bottom)
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Function
    private func getUserFirstName() -> String {
        guard let displayName = viewModel.user?.displayName else {
            return "User"
        }
        
        let components = displayName.components(separatedBy: " ")
        return components.first ?? displayName
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
