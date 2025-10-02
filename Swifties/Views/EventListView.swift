//
//  EventListView.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

import SwiftUI
import FirebaseFirestore

struct EventListView: View {
    @StateObject var viewModel: EventListViewModel
    @State private var searchText = ""
    @State private var isMapView = false

    // Filtrar eventos según búsqueda
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

                CustomTopBar(title: "Events", showNotificationButton: true) {
                    print("Notification tapped")
                }
                
                // Contenido principal
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Cargando eventos…")
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
                       
                            SearchBar(searchText: $searchText)
                                .padding(.top, 16)
                            
                            // Filtros y cambio a vista mapa
                            FilterToggle(isMapView: $isMapView)
                            
                     
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Activities")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                
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
            }
        }
        .onAppear {
            // Evitar recarga en el preview
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.loadEvents()
            }
        }
    }
}

#Preview {
    let mockVM = EventListViewModel()
    mockVM.events = [
        Event(
            id: "1",
            title: "Rock Fest",
            name: "Concierto",
            description: "Música en vivo",
            type: "Concert",
            category: "Música",
            active: true,
            eventType: ["Music", "Concert"],
            location: Event.Location(
                city: "Bogotá",
                type: "Indoor",
                address: "Calle 123",
                coordinates: [4.6097, -74.0817]
            ),
            schedule: Event.Schedule(
                days: ["Friday", "Saturday"],
                times: ["18:00", "20:00"]
            ),
            metadata: Event.Metadata(
                imageUrl: "https://example.com/image.jpg",
                tags: ["rock", "live"],
                durationMinutes: 120,
                cost: "$50"
            ),
            stats: Event.EventStats(
                popularity: 85,
                totalCompletions: 150,
                rating: 4.5
            ),
            weatherDependent: false,
            created: Timestamp(date: Date())
        ),
        Event(
            id: "2",
            title: "Art Expo",
            name: "Exposición",
            description: "Arte moderno",
            type: "Exhibition",
            category: "Arte",
            active: true,
            eventType: ["Art", "Exhibition"],
            location: Event.Location(
                city: "Bogotá",
                type: "Indoor",
                address: "Carrera 7",
                coordinates: [4.6533, -74.0836]
            ),
            schedule: Event.Schedule(
                days: ["Monday", "Tuesday", "Wednesday"],
                times: ["10:00", "14:00"]
            ),
            metadata: Event.Metadata(
                imageUrl: "https://example.com/art.jpg",
                tags: ["art", "modern"],
                durationMinutes: 90,
                cost: "Free"
            ),
            stats: Event.EventStats(
                popularity: 70,
                totalCompletions: 200,
                rating: 4.8
            ),
            weatherDependent: false,
            created: Timestamp(date: Date())
        )
    ]
    return EventListView(viewModel: mockVM)
}
