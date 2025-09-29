//
//  HomeView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack {
                CustomTopBar(title: "Hi, Juliana!", showNotificationButton: true) {
                    print("Notifications tapped")
                }
                
                ScrollView {
                    VStack (spacing: 10) {
                        HStack {
                            Text("What's on your mind today?")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .frame(height: 15)
                            
                            Spacer()
                        }
                        .padding(.top, 20)
                        
                        HStack {
                            Text("Choose what fits you best!")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding()
                                .frame(height: 15)
                            
                            Spacer()
                        }
                        .padding(.bottom, 20)
                        
                        HStack (spacing: 15) {
                            Button {
                                print("Weekly Challenge")
                            } label: {
                                Text("Weekly Challenge")
                                    .frame(width: 120, height: 80)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("appBlue"))
                            
                            Button {
                                print("Personality Quiz")
                            } label: {
                                Text("Personality Quiz")
                                    .frame(width: 120, height: 80)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("appRed"))
                        }
                        
                        HStack (spacing: 15) {
                            Button {
                                print("Wish me Luck")
                            } label: {
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
                                .frame(height: 15)
                            
                            Spacer()
                        }
                        .padding(.top, 20)
                        
                        EventInfoPod(imagePath: "evento",
                                     title: "Daily Marathon",
                                     titleColor: Color("appOcher"),
                                     description: "Have a blast with us on our daily marathon!",
                                     timeText: "Today, 10am",
                                     walkingMinutes: 8)
                        .padding()
                        
                        HStack {
                            Text("Close to you")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .frame(height: 15)
                            
                            Spacer()
                        }
                        
                        EventInfoPod(imagePath: "evento",
                                     title: "Kaldivia",
                                     titleColor: Color("appBlue"),
                                     description: "Have a cup of coffee during your free period!",
                                     timeText: "Today, all-day",
                                     walkingMinutes: 6)
                        .padding()
                        
                        EventInfoPod(imagePath: "evento",
                                     title: "Cívico Pets",
                                     titleColor: Color("appOcher"),
                                     description: "Bring your pets to the Civic Center",
                                     timeText: "Tomorrow, 8-10am",
                                     walkingMinutes: 4)
                        .padding()
                    }
                }
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

#Preview {
    HomeView()
}
