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

    // Filter events by search
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
        NavigationStack {
            ZStack {
                Color("appPrimary").ignoresSafeArea()

                VStack(spacing: 0) {
                    CustomTopBar(title: "Events", showNotificationButton: true) {
                        print("Notification tapped")
                    }

                    // Main content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading events…")
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
                            Button("Retry") {
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

                                // Filters and switch to map view
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
                                        Text(searchText.isEmpty ? "No events available" : "No events found")
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                    } else {
                                        VStack(spacing: 12) {
                                            ForEach(filteredEvents) { event in
                                                NavigationLink(destination: EventDetailView(event: event)) {
                                                    EventInfo(
                                                        imagePath: "theater_event",
                                                        title: event.name,
                                                        titleColor: Color.orange,
                                                        description: event.description,
                                                        timeText: event.schedule.times.first ?? "Time TBD",
                                                        walkingMinutes: 5,
                                                        location: event.location?.address ?? event.category
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
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
                // Avoid reloading in preview
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                    viewModel.loadEvents()
                }
            }
        }
    }
}

#Preview {
    let mockVM = EventListViewModel()
    let mockEvents: [Event] = [
        Event(
            id: "1",
            title: "Rock Fest",
            name: "Concert",
            description: "Live music",
            type: "Concert",
            category: "Music",
            active: true,
            eventType: "Music",
            location: Event.Location(
                city: "Bogotá",
                type: "Indoor",
                address: "123 Street",
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
                cost: Event.Cost(amount: 50, currency: "USD")
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
            name: "Exhibition",
            description: "Modern art",
            type: "Exhibition",
            category: "Art",
            active: true,
            eventType: "Art",
            location: Event.Location(
                city: "Bogotá",
                type: "Indoor",
                address: "7th Avenue",
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
                cost: Event.Cost(amount: 0, currency: "FREE")
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
    mockVM.events = mockEvents
    return EventListView(viewModel: mockVM)
}

