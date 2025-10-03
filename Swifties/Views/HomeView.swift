
//  HomeView.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 29/09/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var selectedTab = 0

    // Estado para navegar a WishMeLuck
    @State private var navigateToWishMeLuck = false

    var body: some View {
        NavigationView {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()

                VStack {
                    CustomTopBar(
                        title: "Hi, \(getUserFirstName())!",
                        showNotificationButton: true
                    ) {
                        print("Notifications tapped")
                    }

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

                            HStack (spacing: 15) {
                                // Botón Wish Me Luck
                                Button {
                                    navigateToWishMeLuck = true
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

                            // ... resto de tu contenido
                            HStack {
                                Text("Daily Recommendation")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .frame(minHeight: 10)

                                Spacer()
                            }
                            .padding(.top, 20)

                            EventInfo(imagePath: "evento",
                                         title: "Daily Marathon",
                                         titleColor: Color("appOcher"),
                                         description: "Have a blast with us on our daily marathon!",
                                         timeText: "Today, 10am",
                                         walkingMinutes: 8,
                                         location: "Lleras"
                            ).padding(.horizontal, 16)

                            // ... otros eventos
                        }
                    }

                    // NavigationLink invisible que se activa al tocar el botón
                    NavigationLink(
                        destination: Magic8BallView(),
                        isActive: $navigateToWishMeLuck,
                        label: { EmptyView() }
                    )
                }
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        .navigationViewStyle(.stack)
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
