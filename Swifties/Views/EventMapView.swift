//
//  EventMapView.swift
//  Swifties
//
//  Created by Assistant on 10/3/25.
//

import SwiftUI
import MapKit

/// The geographic coordinates for Bogotá, Colombia.
private let bogotaCoordinates = CLLocationCoordinate2D(latitude: 4.6533, longitude: -74.0836)

struct EventMapView: View {
    let events: [Event]
    @Binding var selectedEvent: Event?
    var onSelect: ((Event) -> Void)?

    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(center: bogotaCoordinates,
                                                   span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))

    // Calculate nearest N events using Haversine distance
    private func nearestEvents(from location: CLLocation?, count: Int) -> [Event] {
        guard let location = location else { return events }
        let withDistance: [(Event, CLLocationDistance)] = events.compactMap { event in
            guard let coords = event.location?.coordinates, coords.count == 2 else { return nil }
            let eventLocation = CLLocation(latitude: coords[0], longitude: coords[1])
            return (event, location.distance(from: eventLocation))
        }
        .sorted { $0.1 < $1.1 }

        return Array(withDistance.prefix(count).map { $0.0 })
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            ForEach(nearestEvents(from: locationManager.lastLocation, count: 10)) { event in
                let coords = event.location?.coordinates ?? []
                let latitude = coords.first ?? 0
                let longitude = (coords.count > 1 ? coords[1] : 0)
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                Annotation(event.title ?? "Event", coordinate: coordinate) {
                    Button {
                        selectedEvent = event
                        onSelect?(event)
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                            .shadow(radius: 2)
                    }
                }
            }
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
            if let userLocation = locationManager.lastLocation?.coordinate {
                region.center = userLocation
                region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            }
        }
        .onReceive(locationManager.$lastLocation) { location in
            guard let coord = location?.coordinate else { return }
            withAnimation {
                region.center = coord
            }
        }
    }
}

struct EventMapView_Previews: PreviewProvider {
    static var previews: some View {
        EventMapView(events: [], selectedEvent: .constant(nil), onSelect: nil)
    }
}
