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
    private var offlineMessage: String {
        validEvents.isEmpty
            ? "No network connection - Cannot load map view"
            : "No network connection - Showing cached version"
    }
    
    // Anchored menu state
    @State private var menuEvent: Event?
    @State private var menuCoordinate: CLLocationCoordinate2D?
    @State private var menuPoint: CGPoint = .zero
    @State private var mapSize: CGSize = .zero
    @State private var showMenu: Bool = false
    
    // Alert state for unavailable directions
    @State private var showDirectionsUnavailableAlert: Bool = false
    
    // Layout constants for the popover menu
    private let menuSize = CGSize(width: 220, height: 110)
    private let menuPadding: CGFloat = 12
    private let pinOffsetAbove: CGFloat = 44 // approximate offset above pin for menu placement
    private let sideSpacing: CGFloat = 8
    private let topBottomSpacing: CGFloat = 8
    
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
        guard networkMonitor.isConnected else {
            showDirectionsUnavailableAlert = true
            return
        }
        guard let coords = event.location?.coordinates, coords.count == 2 else { return }
        let coordinate = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.name
        
        AnalyticsService.shared.logDirectionRequest(
            eventId: event.id ?? "unknown",
            eventName: event.name
        )
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
    
    // Compute a clamped position for the menu to ensure it stays on-screen
    private func clampedMenuPosition(from anchor: CGPoint, containerSize: CGSize) -> CGPoint {
        var proposedX = anchor.x + menuPadding
        var proposedY = anchor.y - pinOffsetAbove
        proposedY -= (menuSize.height / 2)
        let minX = sideSpacing
        let maxX = containerSize.width - sideSpacing - menuSize.width
        proposedX = min(max(proposedX, minX), maxX)
        let minY = topBottomSpacing
        let maxY = containerSize.height - topBottomSpacing - menuSize.height
        proposedY = min(max(proposedY, minY), maxY)
        return CGPoint(x: proposedX, y: proposedY)
    }
    
    // Background tap to dismiss
    private var backgroundDismissOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showMenu = false
                    menuEvent = nil
                    menuCoordinate = nil
                }
            }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                Color.clear.onAppear { mapSize = geo.size }
                Color.clear.onChange(of: geo.size) { _, newValue in mapSize = newValue }
                
                MapReader { proxy in
                    Map(initialPosition: .region(region)) {
                        ForEach(validEvents) { event in
                            if let coords = event.location?.coordinates, coords.count == 2 {
                                let coordinate = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                                
                                Annotation(event.title, coordinate: coordinate) {
                                    Button {
                                        selectedEvent = event
                                        menuEvent = event
                                        menuCoordinate = coordinate
                                        
                                        let point = proxy.convert(coordinate, to: .local) ?? .zero
                                        menuPoint = point
                                        let clamped = clampedMenuPosition(from: point, containerSize: geo.size)
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            showMenu = true
                                        }
                                        DispatchQueue.main.async {
                                            menuPoint = clamped
                                        }
                                    } label: {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.pink)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                        }
                        
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
                    .overlay(alignment: .topLeading) {
                        if !networkMonitor.isConnected {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.red)
                                Text(offlineMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding()
                        }
                    }
                    .overlay {
                        if showMenu {
                            backgroundDismissOverlay
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        VStack {
                            Spacer()
                            if locationManager.lastLocation != nil {
                                HStack {
                                    Spacer()
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
                                    .padding(.trailing, 16)
                                    .disabled(!networkMonitor.isConnected)
                                    .opacity(networkMonitor.isConnected ? 1.0 : 0.5)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .overlay {
                        if showMenu, let event = menuEvent {
                            ContextualEventMenu(
                                title: event.name,
                                isDirectionsEnabled: networkMonitor.isConnected,
                                onDirections: {
                                    if networkMonitor.isConnected {
                                        openDirections(to: event)
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showMenu = false
                                        }
                                    } else {
                                        showDirectionsUnavailableAlert = true
                                    }
                                },
                                onInfo: {
                                    onSelect?(event)
                                    selectedEvent = event
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showMenu = false
                                    }
                                }
                            )
                            .frame(width: menuSize.width, height: menuSize.height)
                            .position(menuPoint)
                            .onChange(of: geo.size) { _, newSize in
                                if let coord = menuCoordinate {
                                    let point = proxy.convert(coord, to: .local) ?? .zero
                                    menuPoint = clampedMenuPosition(from: point, containerSize: newSize)
                                } else {
                                    let x = min(max(menuPoint.x, sideSpacing), newSize.width - sideSpacing - menuSize.width)
                                    let y = min(max(menuPoint.y, topBottomSpacing), newSize.height - topBottomSpacing - menuSize.height)
                                    menuPoint = CGPoint(x: x, y: y)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNearbyEvents) {
            NearbyEventsSheet(
                nearbyEvents: nearestEvents(from: locationManager.lastLocation, count: 5),
                onEventTap: { event in
                    if let coords = event.location?.coordinates, coords.count == 2 {
                        withAnimation {
                            region.center = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
                            region.span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        }
                    }
                    selectedEvent = event
                    onSelect?(event)
                    showNearbyEvents = false
                },
                onDirectionRequest: { event in
                    if networkMonitor.isConnected {
                        openDirections(to: event)
                    } else {
                        showDirectionsUnavailableAlert = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Service Unavailable", isPresented: $showDirectionsUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Directions are unavailable while offline. Please connect to the internet and try again.")
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Contextual Menu View
private struct ContextualEventMenu: View {
    let title: String
    let isDirectionsEnabled: Bool
    let onDirections: () -> Void
    let onInfo: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Divider()
            
            HStack(spacing: 12) {
                Button(action: onDirections) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        Text("Get Directions")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(!isDirectionsEnabled)
                .opacity(isDirectionsEnabled ? 1.0 : 0.5)
            }
            
            Button(action: onInfo) {
                HStack {
                    Image(systemName: "info.circle.fill")
                    Text("Event Info")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
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
            ZStack {
                Circle()
                    .fill(Color(red: 0.89, green: 0.58, blue: 0.31))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
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
