//
//  EventsListView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/09/25.
//

import SwiftUI

struct EventsListView: View {
    @State private var searchText = ""
    @State private var isMapView = false
    @State private var selectedTab = 2 // Events tab is selected
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomTopBar(title: "Events", showNotificationButton: true) {
                    // Handle notification tap
                    print("Notification tapped")
                }
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Search Bar
                        SearchBar(searchText: $searchText)
                            .padding(.top, 16)
                        
                        // Filter and Map view toggle
                        FilterToggle(isMapView: $isMapView)
                        
                        // Activities section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Activities")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Events list
                            VStack(spacing: 12) {
                                EventInfoPod(
                                    imagePath: "theater_event",
                                    title: "Obra de teatro",
                                    titleColor: Color.orange,
                                    description: "Vive la magia del teatro con una obra que te atrapará desde el primer acto.",
                                    timeText: "Tomorrow 6:00 pm",
                                    walkingMinutes: 2,
                                    location: "El bobo"
                                )
                                
                                EventInfoPod(
                                    imagePath: "theater_event",
                                    title: "TITLE",
                                    titleColor: Color.orange,
                                    description: "Description",
                                    timeText: "Tomorrow 9:00 pm",
                                    walkingMinutes: 5,
                                    location: "Plaza LI"
                                )
                                
                                EventInfoPod(
                                    imagePath: "theater_event",
                                    title: "TITLE",
                                    titleColor: Color.orange,
                                    description: "Description",
                                    timeText: "Monday 2:00 pm",
                                    walkingMinutes: 4,
                                    location: "C Block"
                                )
                                
                                EventInfoPod(
                                    imagePath: "theater_event",
                                    title: "TITLE",
                                    titleColor: Color.orange,
                                    description: "Description",
                                    timeText: "Monday 4:00 pm",
                                    walkingMinutes: 2,
                                    location: "B Block"
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                        
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
    EventsListView()
}
