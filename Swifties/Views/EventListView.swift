//
//  EventListView.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

import SwiftUI
import FirebaseFirestore
import MapKit

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
                    CustomTopBar(title: "Events", showNotificationButton: true, onBackTap:  {
                        print("Notification tapped")
                    })

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
                        VStack(spacing: 0) {
                            // Keep scroll for list mode only, but show search + toggle above map as well
                            VStack(spacing: 16) {
                                SearchBar(searchText: $searchText)
                                    .padding(.top, 16)

                                // Filters and switch to map view
                                FilterToggle(isMapView: $isMapView)
                            }

                            if isMapView {
                                // Map occupies remaining space under bars
                                EventMapContainerView(events: filteredEvents)
                            } else {
                                ScrollView {
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
                                .background(Color("appPrimary"))
                            }
                        }
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

    // Helper container to manage selection and actions from map
    @ViewBuilder
    private func EventMapContainerView(events: [Event]) -> some View {
        EventMapContent(events: events)
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

struct EventMapContent: View {
    let events: [Event]
    @State private var selectedEvent: Event?
    @State private var showActionSheet = false

    var body: some View {
        ZStack {
            EventMapView(events: events, selectedEvent: $selectedEvent) { event in
                selectedEvent = event
                showActionSheet = true
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(title: Text(selectedEvent?.name ?? "Event"), buttons: [
                .default(Text("View Details"), action: {
                    // Navigate to details using a temporary link via NavigationStack environment
                    // We will present a sheet instead for simplicity
                }),
                .default(Text("Get Directions"), action: {
                    if let event = selectedEvent { openDirections(for: event) }
                }),
                .cancel({ selectedEvent = nil })
            ])
        }
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                EventDetailView(event: event)
            }
        }
    }

    private func openDirections(for event: Event) {
        guard let coords = event.location?.coordinates, coords.count == 2 else { return }
        
        let lat = coords[0]
        let lon = coords[1]
        let name = event.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Selected event"

        // Try Google Maps application, then Google Maps web and fallback to Apple Maps
        if let url = URL(string: "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=walking"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)&travelmode=walking&destination_place_id=&destination_name=\(name)") {
            UIApplication.shared.open(web)
        } else {
            let mapItem: MKMapItem
            if #available(iOS 26.0, *) {
                let coordinate = CLLocation(latitude: lat, longitude: lon)
                let address = MKAddress(fullAddress: "", shortAddress: event.location?.address ?? "")
                mapItem = MKMapItem(location: coordinate, address: address)
            } else {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let placemark = MKPlacemark(coordinate: coordinate)
                mapItem = MKMapItem(placemark: placemark)
            }
            mapItem.name = event.name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        }
    }
}
