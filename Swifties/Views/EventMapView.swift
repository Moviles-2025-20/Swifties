//
//  EventMapView.swift
//  Swifties
//
//

import SwiftUI
import MapKit
import Network

/// The geographic coordinates for Bogotá, Colombia.
private let bogotaCoordinates = CLLocationCoordinate2D(latitude: 4.6533, longitude: -74.0836)

struct EventMapView: View {
    let events: [Event]
    @Binding var selectedEvent: Event?
    var onSelect: ((Event) -> Void)?
    
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(center: bogotaCoordinates,
                                                   span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
    @State private var showNearbyEvents = false
    @Environment(\.dismiss) var dismiss

    @StateObject private var networkMonitor = NetworkMonitorService.shared
    private let offlineMessage = "No network connection  - Cannot load map view"
    
    // Filter events with valid coordinates
    private var validEvents: [Event] {
        events.filter { event in
            guard let coords = event.location?.coordinates,
                  coords.count == 2,
                  coords[0] != 0 || coords[1] != 0 else {
                print("Invalid coordinates for event: \(event.name)")
                return false
            }
            return true
        }
    }
    
    // Calculate nearest N events using Haversine distance
    private func nearestEvents(from location: CLLocation?, count: Int) -> [(event: Event, distance: CLLocationDistance)] {
        guard let location = location else {
            return validEvents.prefix(count).map { ($0, 0) }
        }
        
        let withDistance: [(Event, CLLocationDistance)] = validEvents.compactMap { event in
            guard let coords = event.location?.coordinates, coords.count == 2 else { return nil }
            let eventLocation = CLLocation(latitude: coords[0], longitude: coords[1])
            return (event, location.distance(from: eventLocation))
        }
        .sorted { $0.1 < $1.1 }
        
        return Array(withDistance.prefix(count).map { ($0, $1) })
    }
    
    // Function to open directions in Apple Maps
    private func openDirections(to event: Event) {
        print("🔵 [DEBUG] openDirections called for event: \(event.name)")
        
        guard let coords = event.location?.coordinates, coords.count == 2 else {
            print("❌ Cannot open directions: Invalid coordinates")
            return
        }
        
        print("🗺️ Valid coordinates found: \(coords)")
        
        let coordinate = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.name
        
        // Log analytics when directions are requested
        print("📊 About to call AnalyticsService.logDirectionRequest")
        let eventIdToLog = event.id ?? "unknown"
        print("   - Event ID: \(eventIdToLog)")
        print("   - Event Name: \(event.name)")
        
        AnalyticsService.shared.logDirectionRequest(
            eventId: eventIdToLog,
            eventName: event.name
        )
        
        print("✅ AnalyticsService.logDirectionRequest called successfully")
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
        
        print("🚗 Apple Maps opened")
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Map
            Map(initialPosition: .region(region)) {
                ForEach(validEvents) { event in
                    if let coords = event.location?.coordinates,
                       coords.count == 2 {
                        let coordinate = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                        
                        Annotation(event.title, coordinate: coordinate) {
                            Button {
                                selectedEvent = event
                                onSelect?(event)
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.pink)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                
                // User location annotation
                if let userLocation = locationManager.lastLocation?.coordinate {
                    Annotation("You", coordinate: userLocation) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                    }
                }
            }
            
            if !networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(.orange)
                    Text(offlineMessage)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding()
            } else {
                // Floating Action Button
                VStack {
                    Spacer()
                    
                    if locationManager.lastLocation != nil {
                        Button(action: {
                            showNearbyEvents = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16))
                                Text("Close Events")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.pink)
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .onAppear {
            if networkMonitor.isConnected {
                locationManager.requestWhenInUseAuthorization()
                if let userLocation = locationManager.lastLocation?.coordinate {
                    region.center = userLocation
                    region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                }
            } else {
                print(offlineMessage)
            }
        }
        .onReceive(locationManager.$lastLocation) { location in
            guard networkMonitor.isConnected, let coord = location?.coordinate else { return }
            withAnimation {
                region.center = coord
            }
        }
        .sheet(isPresented: $showNearbyEvents) {
            NearbyEventsSheet(
                nearbyEvents: nearestEvents(from: locationManager.lastLocation, count: 5),
                onEventTap: { event in
                    showNearbyEvents = false
                    if let coords = event.location?.coordinates, coords.count == 2 {
                        withAnimation {
                            region.center = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                            region.span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedEvent = event
                        onSelect?(event)
                    }
                },
                onDirectionRequest: { event in
                    openDirections(to: event)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .navigationBarHidden(true)
    }
}

struct NearbyEventsSheet: View {
    let nearbyEvents: [(event: Event, distance: CLLocationDistance)]
    let onEventTap: (Event) -> Void
    let onDirectionRequest: (Event) -> Void
    
    private func distanceText(meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title section
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(Color(red: 0.89, green: 0.58, blue: 0.31))
                Text("Close Events")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(nearbyEvents.count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.89, green: 0.58, blue: 0.31))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.89, green: 0.58, blue: 0.31).opacity(0.2))
                    .cornerRadius(12)
            }
            .padding()
            
            Divider()
            
            // Events list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(nearbyEvents.enumerated()), id: \.element.event.id) { index, item in
                        NearbyEventRow(
                            rank: index + 1,
                            event: item.event,
                            distance: distanceText(meters: item.distance),
                            onTap: {
                                onEventTap(item.event)
                            },
                            onDirectionTap: {
                                onDirectionRequest(item.event)
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

struct NearbyEventRow: View {
    let rank: Int
    let event: Event
    let distance: String
    let onTap: () -> Void
    let onDirectionTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(Color(red: 0.89, green: 0.58, blue: 0.31))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Event info (tappable)
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label(event.location?.city ?? "Unknown", systemImage: "building.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !distance.isEmpty {
                            Text(distance)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.89, green: 0.58, blue: 0.31))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.89, green: 0.58, blue: 0.31).opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                    
                    let tags = event.metadata.tags
                    if !tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Direction button
            Button(action: onDirectionTap) {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.pink)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct EventMapView_Previews: PreviewProvider {
    static var previews: some View {
        EventMapView(events: [], selectedEvent: .constant(nil), onSelect: nil)
    }
}
