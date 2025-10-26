import Foundation
import SwiftUI
import CoreMotion
import FirebaseFirestore
import FirebaseAnalytics
import Network

struct WishMeLuckView: View {
    @StateObject private var viewModel = WishMeLuckViewModel()
    @State private var animateBall = false
    @State private var isShaking = false
    @State private var showEventDetail = false
    @State private var fullEventForDetail: Event?
    @State private var isLoadingFullEvent = false
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    private let offlineMessage = "No network connection - Couldn't fetch events"
    
    private let db = Firestore.firestore(database: "default")
    
    // Accelerometer
    private let motionManager = CMMotionManager()
    @State private var lastShakeTime: Date?
    private let shakeThreshold: Double = 2.5
    private let shakeCooldown: TimeInterval = 3.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack {
                    CustomTopBar(
                        title: "Wish Me Luck",
                        showNotificationButton: true,
                        onBackTap: {}
                    )
                    
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                            Text(offlineMessage)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Retry") {
                                if networkMonitor.isConnected {
                                    Task { await viewModel.calculateDaysSinceLastWished() }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding([.horizontal, .top], 20)
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                // MARK: - Header Section
                                HeaderSection(daysSinceLastWished: viewModel.daysSinceLastWished)
                                    .padding(.horizontal, 20)
                                
                                // MARK: - Magic 8-Ball
                                Magic8BallCard(
                                    isLoading: viewModel.isLoading,
                                    animateBall: $animateBall
                                )
                                .padding(.horizontal, 20)
                                
                                // MARK: - Motivational Message
                                if let _ = viewModel.currentEvent {
                                    MotivationalMessageCard(message: viewModel.getMotivationalMessage())
                                        .padding(.horizontal, 20)
                                }
                                
                                // MARK: - Event Preview or Empty State
                                if let event = viewModel.currentEvent {
                                    EventPreviewCard(event: event, isLoadingDetail: isLoadingFullEvent)
                                        .padding(.horizontal, 20)
                                        .onTapGesture {
                                            loadFullEventAndShowDetail(eventId: event.id)
                                        }
                                } else if !viewModel.isLoading {
                                    EmptyStateCard()
                                        .padding(.horizontal, 20)
                                }
                                
                                // MARK: - Wish Me Luck Button
                                WishMeLuckButton(isLoading: viewModel.isLoading) {
                                    Task {
                                        await triggerWish()
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            .padding(.top, 10)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEventDetail) {
                if let fullEvent = fullEventForDetail {
                    EventDetailView(event: fullEvent)
                }
            }
            
            .task {
                if networkMonitor.isConnected {
                    await viewModel.calculateDaysSinceLastWished()
                }
                startAccelerometerUpdates()
            }
            .onDisappear {
                stopAccelerometerUpdates()
            }
        }
    }
    
    // MARK: - Load Full Event and Show Detail
    private func loadFullEventAndShowDetail(eventId: String) {
        guard networkMonitor.isConnected else {
            print(offlineMessage)
            return
        }
        
        isLoadingFullEvent = true
        
        db.collection("events").document(eventId).getDocument { document, error in
            DispatchQueue.main.async {
                isLoadingFullEvent = false
                
                if let error = error {
                    print("Error loading full event: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("Event document not found")
                    return
                }
                                
                // Try to parse using Codable first
                if let event = try? document.data(as: Event.self) {
                    print("Successfully parsed event using Codable")
                    fullEventForDetail = event

                 
                    AnalyticsService.shared.logActivitySelection(
                        activityId: event.id ?? "unknown_event",
                        discoveryMethod: .wishMeLuck
                    )

                    showEventDetail = true
                } else {
                    print("Codable parsing failed, attempting manual parse")
                    if let event = parseEventManually(documentId: document.documentID, data: document.data() ?? [:]) {
                        print("Successfully parsed event manually")
                        fullEventForDetail = event
                        
                 
                        AnalyticsService.shared.logActivitySelection(
                            activityId: event.id ?? "unknown_event",
                            discoveryMethod: .wishMeLuck
                        )
                        
                        showEventDetail = true
                    } else {
                        print("❌ Manual parsing also failed")
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Event Parsing (Fallback)
    private func parseEventManually(documentId: String, data: [String: Any]) -> Event? {
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let category = data["category"] as? String else {
            print("❌ Missing required fields: name, description, or category")
            return nil
        }
        
        // Location parsing
        var location: EventLocation? = nil
        if let locationData = data["location"] as? [String: Any] {
            location = EventLocation(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                coordinates: locationData["coordinates"] as? [Double] ?? [],
                type: locationData["type"] as? String ?? ""
            )
        }
        
        // Schedule parsing
        var schedule = EventSchedule(days: [], times: [])
        if let scheduleData = data["schedule"] as? [String: Any] {
            schedule = EventSchedule(
                days: scheduleData["days"] as? [String] ?? [],
                times: scheduleData["times"] as? [String] ?? []
            )
        }
        
        // Metadata parsing
        var metadata = EventMetadata(
            cost: EventCost(amount: 0, currency: "COP"),
            durationMinutes: 0,
            imageUrl: "",
            tags: []
        )
        if let metadataData = data["metadata"] as? [String: Any] {
            var cost = EventCost(amount: 0, currency: "COP")
            if let costData = metadataData["cost"] as? [String: Any] {
                let amount = costData["amount"] as? Int ?? 0
                let currency = costData["currency"] as? String ?? "COP"
                cost = EventCost(amount: amount, currency: currency)
            }
            
            metadata = EventMetadata(
                cost: cost,
                durationMinutes: metadataData["duration_minutes"] as? Int ?? 0,
                imageUrl: metadataData["image_url"] as? String ?? "",
                tags: metadataData["tags"] as? [String] ?? []
            )
        }
        
        // Stats parsing
        var stats = EventStats(popularity: 0, rating: 0, totalCompletions: 0)
        if let statsData = data["stats"] as? [String: Any] {
            stats = EventStats(
                popularity: statsData["popularity"] as? Int ?? 0,
                rating: statsData["rating"] as? Int ?? 0,
                totalCompletions: statsData["total_completions"] as? Int ?? 0
            )
        }
        
        var event = Event(
            activetrue: data["active"] as? Bool ?? true,
            category: category,
            created: data["created"] as? String ?? "",
            description: description,
            eventType: data["event_type"] as? String ?? "",
            location: location,
            metadata: metadata,
            name: name,
            schedule: schedule,
            stats: stats,
            title: data["title"] as? String ?? name,
            type: data["type"] as? String ?? "",
            weatherDependent: data["weather_dependent"] as? Bool ?? false
        )
        
        // Manually set the document ID
        event.id = documentId
        
        return event
    }
    
    // MARK: - Trigger Wish
    private func triggerWish() async {
        guard networkMonitor.isConnected else {
            print(offlineMessage)
            return
        }
        
        AnalyticsService.shared.logWishMeLuckUsed()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            animateBall = true
        }
        
        await viewModel.wishMeLuck()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                animateBall = false
            }
        }
    }

    // MARK: - Accelerometer
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            guard let data = data, error == nil else { return }
            
            let acceleration = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            
            if acceleration > shakeThreshold {
                handleShake()
            }
        }
    }
    
    private func stopAccelerometerUpdates() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func handleShake() {
        let now = Date()
        
        if let lastShake = lastShakeTime,
           now.timeIntervalSince(lastShake) < shakeCooldown {
            return
        }
        
        guard !viewModel.isLoading else { return }
        
        lastShakeTime = now
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            await triggerWish()
        }
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    let daysSinceLastWished: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Days since last wished")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(daysSinceLastWished)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Color("appBlue"))
            
            Text(daysSinceLastWished == 1 ? "day" : "days")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Magic 8-Ball Card
struct Magic8BallCard: View {
    let isLoading: Bool
    @Binding var animateBall: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Shake your phone or tap the button")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 8)
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    Text("8")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(animateBall ? 360 : 0))
                        .animation(.easeInOut(duration: 0.6), value: animateBall)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Motivational Message Card
struct MotivationalMessageCard: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundColor(Color("appOcher"))
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Event Preview Card
struct EventPreviewCard: View {
    let event: WishMeLuckEvent
    let isLoadingDetail: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event Image
            if !event.imageUrl.isEmpty {
                AsyncImage(url: URL(string: event.imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                        .overlay(ProgressView())
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            
            // Event Title
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Event Description
            Text(event.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Tap to view hint
            HStack {
                Spacer()
                if isLoadingDetail {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading details...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap to view details")
                        .font(.caption)
                        .foregroundColor(.appOcher)
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .foregroundColor(.appOcher)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .opacity(isLoadingDetail ? 0.6 : 1.0)
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.sparkles.inverse")
                .font(.system(size: 50))
                .foregroundColor(Color("appBlue").opacity(0.6))
            
            Text("Shake or tap the button below")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("And let the magic 8-ball discover your perfect event!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Wish Me Luck Button
struct WishMeLuckButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                Text(isLoading ? "Finding your event..." : "✨ Wish Me Luck!")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLoading ? Color.gray : Color.appOcher)
            .cornerRadius(16)
        }
        .disabled(isLoading)
    }
}

// MARK: - Preview
struct WishMeLuckView_Previews: PreviewProvider {
    static var previews: some View {
        WishMeLuckView()
    }
}
