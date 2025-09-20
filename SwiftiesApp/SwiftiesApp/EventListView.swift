//
//  EventListView.swift
//  SwiftiesApp
//
//  Created by Natalia Villegas Calderón on 20/09/25.
//

import SwiftUI

struct EventsView: View {
    @State private var searchText = ""
    @State private var isMapView = false
    @State private var selectedTab = 2 // Events tab is selected
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Top Bar
            CustomTopBar(
                title: "Events",
                showNotificationButton: true,
                onNotificationTap: {
                    // Handle notification tap
                    print("Notification tapped")
                }
            )
            
            // Main content
            VStack(spacing: 16) {
                // Search Bar
                SearchBarComponent(searchText: $searchText)
                    .padding(.top, 16)
                
                // Filter and Map view toggle
                FilterToggleComponent(isMapView: $isMapView)
                
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // First event - Obra de teatro
                            EventInfoPod(
                                imagePath: "theater_event", // Replace with your actual image name
                                title: "Obra de teatro",
                                titleColor: Color.orange,
                                description: "Vive la magia del teatro con una obra que te atrapará desde el primer acto.",
                                timeText: "Tomorrow 6:00 pm",
                                walkingMinutes: 2
                            )
                            .overlay(
                                // Location overlay for El bobo
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("El bobo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.top, 20)
                                }
                            )
                            
                            // Second event
                            EventInfoPod(
                                imagePath: "theater_event", // Replace with your actual image name
                                title: "TITLE",
                                titleColor: Color.orange,
                                description: "Description",
                                timeText: "Tomorrow 9:00 pm",
                                walkingMinutes: 5
                            )
                            .overlay(
                                // Location overlay for Plaza LI
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("Plaza LI")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.top, 20)
                                }
                            )
                            
                            // Third event
                            EventInfoPod(
                                imagePath: "theater_event", // Replace with your actual image name
                                title: "TITLE",
                                titleColor: Color.orange,
                                description: "Description",
                                timeText: "Monday 2:00 pm",
                                walkingMinutes: 4
                            )
                            .overlay(
                                // Location overlay for C Block
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("C Block")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.top, 20)
                                }
                            )
                            
                            // Fourth event
                            EventInfoPod(
                                imagePath: "theater_event", // Replace with your actual image name
                                title: "TITLE",
                                titleColor: Color.orange,
                                description: "Description",
                                timeText: "Monday 4:00 pm",
                                walkingMinutes: 2
                            )
                            .overlay(
                                // Location overlay for B Block
                                HStack {
                                    Spacer()
                                    VStack {
                                        Text("B Block")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.top, 20)
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            
            Spacer()
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 34) // Safe area bottom padding
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Preview
struct EventsView_Previews: PreviewProvider {
    static var previews: some View {
        EventsView()
    }
}
