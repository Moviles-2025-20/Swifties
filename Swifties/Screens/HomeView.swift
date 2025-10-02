//
//  HomeView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack {
                // 🔝 Top bar
                CustomTopBar(title: "Hi, Juliana!", showNotificationButton: true) {
                    print("Notifications tapped")
                }
                
                ScrollView {
                    VStack (spacing: 0) {
                        // Pregunta inicial
                        HStack {
                            Text("What's on your mind today?")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .frame(minHeight: 10)
                            Spacer()
                        }
                        .padding(.bottom, 10)
                        
                        // Botones fila 1
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
                        .padding(.bottom, 10)
                        
                        // Botones fila 2
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
                        
                        // Sección Daily Recommendation
                        HStack {
                            Text("Daily Recommendation")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .frame(minHeight: 10)
                            Spacer()
                        }
                        .padding(.top, 20)
                        
                        EventInfo(
                            imagePath: "evento",
                            title: "Daily Marathon",
                            titleColor: Color("appOcher"),
                            description: "Have a blast with us on our daily marathon!",
                            timeText: "Today, 10am",
                            walkingMinutes: 8,
                            location: "Lleras"
                        )
                        .padding(.horizontal, 16)
                        
                        // Sección Close to you
                        HStack {
                            Text("Close to you")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding()
                                .frame(minHeight: 10)
                            Spacer()
                        }
                        .padding(.top, 20)
                        
                        EventInfo(
                            imagePath: "evento",
                            title: "Kaldivia",
                            titleColor: Color("appBlue"),
                            description: "Have a cup of coffee during your free period!",
                            timeText: "Today, all-day",
                            walkingMinutes: 6,
                            location: "S1"
                        )
                        .padding(.bottom)
                        .padding(.horizontal, 16)
                        
                        EventInfo(
                            imagePath: "evento",
                            title: "Cívico Pets",
                            titleColor: Color("appOcher"),
                            description: "Bring your pets to the Civic Center",
                            timeText: "Tomorrow, 8-10am",
                            walkingMinutes: 4,
                            location: "RGD"
                        )
                        .padding(.bottom)
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
