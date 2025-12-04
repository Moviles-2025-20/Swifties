//
//  MainView.swift
//  Swifties
//
//  Created by Imac on 2/10/25.
//

import SwiftUI

struct MainView: View {
    
    // MARK: - Properties
    @State private var selectedTab: Int = 0
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNFCEvent = false
    @State private var nfcEvent: Event?
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contentView(for: selectedTab)
                
                CustomTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationDestination(isPresented: $showNFCEvent) {
                if let event = nfcEvent {
                    EventDetailView(event: event)
                }
            }
            .onAppear {
                // Listen for deep link notifications from SwiftiesApp
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowNFCScavengerHunt"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let url = notification.object as? URL {
                        print("MainView received deep link notification: \(url)")
                        handleNFCDeepLink(url)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Views
    @ViewBuilder
    private func contentView(for tab: Int) -> some View {
        switch tab {
        case 0:
            HomeView()
        case 1:
            EventListView(viewModel: EventListViewModel())
        case 2:
            WishMeLuckView()
        case 3:
            ProfileView()
        default:
            HomeView()
        }
    }
    
    // MARK: - Deep Link Handler
    private func handleNFCDeepLink(_ url: URL) {
        guard url.scheme == "swifties",
              url.host == "scavenger" else {
            return
        }
        
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("📍 Handling NFC event for path: \(path)")
        
        // Create the football event
        if path.contains("football") || !path.isEmpty {
            nfcEvent = createFootballEvent()
            showNFCEvent = true
            print("✅ Opening event detail for: \(nfcEvent?.title ?? "unknown")")
        }
    }
    
    private func createFootballEvent() -> Event {
        var event = Event(
            activetrue: true,
            category: "Sports",
            created: "2025-11-14T09:00:00-05:00",
            description: "Hands-on workshop on advanced football techniques for university students.",
            eventType: "Workshop",
            location: EventLocation(
                address: "Calle 19 #2-70, Bogotá, Colombia",
                city: "Bogotá",
                coordinates: [4.600644, -74.063013],
                type: "Sports Complex"
            ),
            metadata: EventMetadata(
                cost: EventCost(amount: 50, currency: "COP"),
                durationMinutes: 120,
                imageUrl: "https://encrypted-tbn3.gstatic.com/images?q=tbn:ANd9GcQ00GzzodX1gs3-sVT4FnRwQq95ZJiKNbvPbOPL2jaF9XBq6bIPKSrPYBBGr9GgRbwzkjivU9IcGGdq7NOI2EkmRbt8t-9E64fdyF7N5A",
                tags: ["Football", "Training", "Students"]
            ),
            name: "Advanced University Football",
            schedule: EventSchedule(
                days: ["Wednesday"],
                times: ["3:00 PM"]
            ),
            stats: EventStats(
                popularity: 0,
                rating: 3,
                ratingList: [5, 4],
                totalCompletions: 0
            ),
            title: "Football Workshop 2025",
            type: "Practical",
            weatherDependent: true
        )
        
        event.id = "19ph2WwBuiuI0Rgw7t5F"
        return event
    }
}

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
