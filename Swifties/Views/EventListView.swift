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
                                            ForEach(filteredEvents, id: \.title) { event in
                                                NavigationLink(destination: EventDetailView(event: event)) {
                                                    EventInfo(
                                                        imagePath: event.metadata.imageUrl,
                                                        title: event.name,
                                                        titleColor: Color.orange,
                                                        description: event.description,
                                                        timeText: event.schedule.times.first ?? "Time TBD",
                                                        walkingMinutes: 5,
                                                        location: event.location.address
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
            activetrue: true,
            category: "Music",
            created: "2025-10-05T18:00:00-05:00",
            description: "Live rock music concert",
            eventType: "Concert",
            location: EventLocation(
                address: "123 Street",
                city: "Bogotá",
                coordinates: [4.6097, -74.0817],
                type: "Indoor"
            ),
            metadata: EventMetadata(
                cost: EventCost(amount: 50000, currency: "COP"),
                durationMinutes: 120,
                imageUrl: "https://example.com/image.jpg",
                tags: ["rock", "live", "music"]
            ),
            name: "Rock Fest",
            schedule: EventSchedule(
                days: ["Friday", "Saturday"],
                times: ["18:00", "20:00"]
            ),
            stats: EventStats(
                popularity: 85,
                rating: 4,
                totalCompletions: 150
            ),
            title: "Rock Fest 2025",
            type: "Concert",
            weatherDependent: false
        ),
        Event(
            activetrue: true,
            category: "Art",
            created: "2025-10-05T10:00:00-05:00",
            description: "Modern art exhibition",
            eventType: "Exhibition",
            location: EventLocation(
                address: "7th Avenue",
                city: "Bogotá",
                coordinates: [4.6533, -74.0836],
                type: "Indoor"
            ),
            metadata: EventMetadata(
                cost: EventCost(amount: 0, currency: "COP"),
                durationMinutes: 90,
                imageUrl: "https://example.com/art.jpg",
                tags: ["art", "modern", "exhibition"]
            ),
            name: "Art Expo",
            schedule: EventSchedule(
                days: ["Monday", "Tuesday", "Wednesday"],
                times: ["10:00", "14:00"]
            ),
            stats: EventStats(
                popularity: 70,
                rating: 5,
                totalCompletions: 200
            ),
            title: "Art Expo 2025",
            type: "Exhibition",
            weatherDependent: false
        )
    ]
    mockVM.events = mockEvents
    return EventListView(viewModel: mockVM)
}
