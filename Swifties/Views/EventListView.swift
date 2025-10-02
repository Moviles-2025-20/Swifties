//
//  EventListView.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

import SwiftUI

struct EventListView: View {
    @StateObject var viewModel: EventListViewModel
    @State private var searchText = ""
    @State private var isMapView = false
    @State private var selectedTab = 2 // Events tab is selected

    var filteredEvents: [Event] {
        if searchText.isEmpty {
            return viewModel.events
        } else {
            return viewModel.events.filter { event in
                event.name.localizedCaseInsensitiveContains(searchText) ||
                event.description.localizedCaseInsensitiveContains(searchText) ||
                event.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Top Bar
                CustomTopBar(title: "Events", showNotificationButton: true) {
                    print("Notification tapped")
                }
                
                // Indicador de carga
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Cargando eventos...")
                        .foregroundColor(.primary)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("⚠️")
                            .font(.system(size: 50))
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Reintentar") {
                            viewModel.loadEvents()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    Spacer()
                } else {
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
                                
                                // Events list (Firebase)
                                if filteredEvents.isEmpty {
                                    Text(searchText.isEmpty ? "No hay eventos disponibles" : "No se encontraron eventos")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(filteredEvents) { event in
                                            EventInfo(
                                                imagePath: "theater_event",
                                                title: event.name,
                                                titleColor: Color.orange,
                                                description: event.description,
                                                timeText: "Tomorrow 6:00 pm",
                                                walkingMinutes: 5,
                                                location: event.category
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            Spacer(minLength: 80) 
                        }
                    }
                    .background(Color("appPrimary"))
                }
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .onAppear {

            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.loadEvents()
            }
        }
    }
}

#Preview {
    let mockVM = EventListViewModel()
    mockVM.events = [
        Event(id: "1", name: "Concierto", description: "Música en vivo", category: "Música", active: true, title: "Rock Fest", eventType: ["Music"]),
        Event(id: "2", name: "Exposición", description: "Arte moderno", category: "Arte", active: true, title: "Art Expo", eventType: ["Art"])
    ]
    return EventListView(viewModel: mockVM)
}
