//
//  EventListView.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

import SwiftUI
import MapKit
import UIKit
import FirebaseAnalytics

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
                                                ForEach(filteredEvents, id: \.title) { event in
                                                    NavigationLink(
                                                        destination: EventDetailView(event: event),
                                                        label: {
                                                            EventInfo(
                                                                imagePath: event.metadata.imageUrl,
                                                                title: event.name,
                                                                titleColor: Color.appOcher,
                                                                description: event.description,
                                                                timeText: event.schedule.times.first ?? "Time TBD",
                                                                walkingMinutes: 5,
                                                                location: event.location?.address
                                                            )
                                                        }
                                                    )
                                                    .simultaneousGesture(TapGesture().onEnded {
                                                        AnalyticsService.shared.logActivitySelection(
                                                            activityId: event.id ?? "unknown_event",
                                                            discoveryMethod: .manualBrowse
                                                        )
                                                    })


                                                }
                                                .padding(.horizontal, 16)
                                            }
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
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                    viewModel.loadEvents()
                    
                    Analytics.logEvent("activity_discovery_method", parameters: [
                        "method": "manual_browse",
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }

        }
    }

    // Helper container to manage selection and actions from map
    @ViewBuilder
    func EventMapContainerView(events: [Event]) -> some View {
        EventMapContent(events: events)
    }
}

struct EventMapContent: View {
    let events: [Event]
    @State private var selectedEvent: Event?
    @State private var showActionSheet = false
    @State private var showDetailsSheet = false

    var body: some View {
        ZStack {
            EventMapView(events: events, selectedEvent: $selectedEvent) { event in
                selectedEvent = event
                showActionSheet = true
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .confirmationDialog(selectedEvent?.name ?? "Event", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("View Details") {
                showDetailsSheet = true
            }
            Button("Get Directions") {
                if let event = selectedEvent { openDirections(for: event) }
            }
            Button("Cancel", role: .cancel) {
                selectedEvent = nil
            }
        }
        .sheet(isPresented: $showDetailsSheet, onDismiss: { selectedEvent = nil }) {
            NavigationStack {
                if let event = selectedEvent {
                    EventDetailView(event: event)
                } else {
                    EmptyView()
                }
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
            if #available(iOS 18.0, *) {
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

private struct EventListView_PreviewContainer: View {
    let viewModel: EventListViewModel = {
        let vm = EventListViewModel()
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
        vm.events = mockEvents
        return vm
    }()

    var body: some View {
        EventListView(viewModel: viewModel)
    }
}

#Preview {
    EventListView_PreviewContainer()
}
