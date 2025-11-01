import SwiftUI
import MapKit

struct EventMapView: View {
    let events: [Event]
    @Binding var selectedEvent: Event?
    var onSelect: ((Event) -> Void)?
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 4.6533, longitude: -74.0836),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showNearbyEvents = false
    @State private var mapLoadFailed = false
    @State private var mapLoadTimer: Timer?
    @Environment(\.dismiss) var dismiss

    private var validEvents: [Event] {
        events.filter { event in
            guard let coords = event.location?.coordinates,
                  coords.count == 2,
                  coords[0] != 0 || coords[1] != 0 else {
                return false
            }
            return true
        }
    }
    
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
    
    private func openDirections(to event: Event) {
        guard let coords = event.location?.coordinates, coords.count == 2 else {
            print("❌ Cannot open directions: Invalid coordinates")
            return
        }
        
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
    
    var body: some View {
        ZStack(alignment: .top) {
            if mapLoadFailed {
                // Plan Z: Map failed to load
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Map Unavailable")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Unable to load map. Please check your connection and try again.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        mapLoadFailed = false
                        startMapLoadTimer()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.pink)
                        .cornerRadius(25)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                // Normal map view
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
                    // Cancel timer when map appears successfully
                    mapLoadTimer?.invalidate()
                    mapLoadTimer = nil
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    
                    if networkMonitor.isConnected && locationManager.lastLocation != nil {
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
            }
            
            // Start a timer to detect if map fails to load
            startMapLoadTimer()
        }
        .onDisappear {
            mapLoadTimer?.invalidate()
            mapLoadTimer = nil
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
    
    private func startMapLoadTimer() {
        // If map doesn't render within 3 seconds and there's no network, assume failure
        mapLoadTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if !networkMonitor.isConnected {
                mapLoadFailed = true
                print("⚠️ Map load timeout - no network connection")
            }
        }
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
