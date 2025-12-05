import SwiftUI
import MapKit
import UIKit
import FirebaseAnalytics

struct EventListView: View {
    @StateObject var viewModel: EventListViewModel
    @State private var searchText = ""
    @State private var isMapView = false
    @State private var mapOpenedTime: Date?
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    @State private var showNews: Bool = false

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
    
    private var dataSourceIcon: String {
        switch viewModel.dataSource {
        case .memoryCache: return "memorychip"
        case .localStorage: return "internaldrive"
        case .network: return "wifi"
        case .none: return "questionmark"
        }
    }

    private var dataSourceText: String {
        switch viewModel.dataSource {
        case .memoryCache: return "Memory Cache"
        case .localStorage: return "Local Storage"
        case .network: return "Updated from Network"
        case .none: return ""
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary").ignoresSafeArea()

                VStack(spacing: 0) {
                    CustomTopBar(title: "Events", showNotificationButton: true, onNotificationTap: { showNews = true }, onBackTap:  {
                        print("Notification tapped")
                    })
                    
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.red)
                            Text("No Internet Connection")
                                .font(.callout)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    
                    if !viewModel.isLoading && !viewModel.events.isEmpty && !isMapView {
                        HStack {
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Image(systemName: dataSourceIcon)
                                    .foregroundColor(.secondary)
                                Text(dataSourceText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if viewModel.isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Updating...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading events...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                    } else if !networkMonitor.isConnected && viewModel.events.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("No Internet Connection")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("No cached or stored data available")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Text("Please connect to the internet and try again to load events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                if !networkMonitor.isConnected {
                                    offlineAlertMessage = "Still no internet connection - Please check your network settings"
                                    showOfflineAlert = true
                                } else {
                                    viewModel.loadEvents()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        Spacer()
                        
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: getErrorIcon(for: error))
                                .font(.system(size: 60))
                                .foregroundColor(.red.opacity(0.8))
                            
                            Text("Something Went Wrong")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(error)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                if !networkMonitor.isConnected {
                                    offlineAlertMessage = "Cannot retry - No internet connection available"
                                    showOfflineAlert = true
                                } else {
                                    viewModel.loadEvents()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Try Again")
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        Spacer()
                        
                    } else {
                        VStack(spacing: 0) {
                            VStack(spacing: 16) {
                                SearchBar(searchText: $searchText)
                                    .padding(.top, 16)
                                FilterToggle(isMapView: $isMapView)
                            }

                            if isMapView {
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
                                                                timeText: formatEventTime(event: event),
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
            .alert("Connection Required", isPresented: $showOfflineAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(offlineAlertMessage)
            }
            .onChange(of: isMapView) { oldValue, newValue in
                if newValue {
                    mapOpenedTime = Date()
                    AnalyticsService.shared.logMapViewOpened(
                        source: .eventList,
                        eventCount: filteredEvents.count
                    )
                } else if let openedTime = mapOpenedTime {
                    let duration = Date().timeIntervalSince(openedTime)
                    AnalyticsService.shared.logMapViewClosed(durationSeconds: duration)
                    mapOpenedTime = nil
                }
            }
            .onAppear {
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                    EventStorageService.shared.debugStorage()
                    viewModel.loadEvents()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        guard !viewModel.events.isEmpty else {
                            return
                        }
                        logRatingsForCurrentEventsInBackground()
                    }
                    
                    AnalyticsService.shared.logDiscoveryMethod(.manualBrowse)
                }
            }
            .navigationDestination(isPresented: $showNews) {
                NewsView()
            }
        }
    }

    private func getErrorIcon(for error: String) -> String {
        if error.contains("network") || error.contains("connection") {
            return "wifi.slash"
        } else if error.contains("auth") || error.contains("user") {
            return "person.crop.circle.badge.exclamationmark"
        } else {
            return "exclamationmark.triangle"
        }
    }

    @ViewBuilder
    func EventMapContainerView(events: [Event]) -> some View {
        EventMapContent(events: events, viewModel: viewModel)
    }
    
    // MARK: - Ratings analytics (background)
    private func logRatingsForCurrentEventsInBackground() {
        let eventsSnapshot = viewModel.events // capture once
        guard !eventsSnapshot.isEmpty else { return }
        
        Task.detached(priority: .background) {
            for event in eventsSnapshot {
                // Extract valid ratings 1...5 from stats.ratingList (ignore nils and out-of-range)
                let validRatings: [Int] = event.stats.ratingList.compactMap { value in
                    guard let v = value, (1...5).contains(v) else { return nil }
                    return v
                }
                guard !validRatings.isEmpty else { continue } // only with at least 1 rating
                
                // Counts for 1..5
                var counts = [0, 0, 0, 0, 0]
                for r in validRatings { counts[r - 1] += 1 }
                
                let total = counts.reduce(0, +)
                let avg: Double
                if total > 0 {
                    let sum = counts.enumerated().reduce(0) { partial, pair in
                        let (index, count) = pair
                        return partial + (index + 1) * count
                    }
                    avg = Double(sum) / Double(total)
                } else {
                    avg = 0.0
                }
                
                await AnalyticsService.shared.logEventRatingsSnapshot(
                    eventId: event.id ?? "unknown_event",
                    eventName: event.name,
                    average: avg,
                    total: total
                )
            }
        }
    }
}

struct EventMapContent: View {
    let events: [Event]
    let viewModel: EventListViewModel
    @State private var selectedEvent: Event?
    @State private var showDetailsSheet = false

    var body: some View {
        ZStack {
            EventMapView(events: events, selectedEvent: $selectedEvent) { event in
                selectedEvent = event
                showDetailsSheet = true
            }
            .ignoresSafeArea(edges: .bottom)
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
}

private func formatEventTime(event: Event) -> String {
    let day = event.schedule.days.first ?? ""
    let time = event.schedule.times.first ?? "Time TBD"
    if day.isEmpty {
        return time
    } else {
        return "\(day), \(time)"
    }
}

private struct EventListView_PreviewContainer: View {
    let viewModel: EventListViewModel = {
        let vm = EventListViewModel()
        let mockEvents: [Event] = []
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
