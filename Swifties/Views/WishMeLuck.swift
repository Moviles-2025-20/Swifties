import Foundation
import SwiftUI
import CoreMotion
import FirebaseFirestore
import FirebaseAnalytics
import Network
import CoreNFC

struct WishMeLuckView: View {
    @StateObject private var viewModel = WishMeLuckViewModel()
    @State private var animateBall = false
    @State private var isShaking = false
    @State private var showEventDetail = false
    @State private var showNews = false
    @State private var fullEventForDetail: Event?
    @State private var isLoadingFullEvent = false
    @State private var showNoConnectionAlert = false
    
    // NFC Properties
    private let nfcService = NFCWishMeLuckService.shared
    @State private var showNFCButton = NFCNDEFReaderSession.readingAvailable
    @State private var showNFCError = false
    @State private var nfcErrorMessage = ""
    
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    private let offlineMessage = "No network connection - Couldn't fetch events"
    
    private let db = Firestore.firestore(database: "default")
    
    // Accelerometer
    private let motionManager = CMMotionManager()
    @State private var lastShakeTime: Date?
    private let shakeThreshold: Double = 2.5
    private let shakeCooldown: TimeInterval = 3.0
    
    // MARK: - Computed Properties for Data Source Indicator
    private var dataSourceIcon: String {
        switch viewModel.dataSource {
        case .memoryCache: return "memorychip"
        case .realmStorage: return "internaldrive"
        case .network: return "wifi"
        case .none: return "questionmark"
        }
    }
    
    private var dataSourceText: String {
        switch viewModel.dataSource {
        case .memoryCache: return "Memory Cache"
        case .realmStorage: return "Local Storage (Realm)"
        case .network: return "Updated from Network"
        case .none: return ""
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack {
                    CustomTopBar(
                        title: "Wish Me Luck",
                        showNotificationButton: true,
                        onBackTap: { showNews = true }
                    )
                    
                    // Connection status banner
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
                    
                    // Data Source Indicator
                    if !viewModel.isLoading && viewModel.dataSource != .none {
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
                        
                        // Pending sync indicator (separate row, also centered)
                        if viewModel.hasPendingWishUpdate {
                            HStack {
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.orange)
                                    Text("Pending sync")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                    }
                    
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
                            
                            // MARK: - Event Preview or Error/Empty State
                            if viewModel.isLoading {
                                // Loading state
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Finding your perfect event…")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 20)
                                
                            } else if let error = viewModel.errorMessage {
                                // Error state with context-aware messages
                                VStack(spacing: 16) {
                                    Image(systemName: getErrorIcon(for: error))
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    
                                    Text(error)
                                        .font(.body)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                    
                                    Text(getErrorHint(for: error))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                    
                                    if viewModel.dataSource == .none && networkMonitor.isConnected {
                                        Button {
                                            Task {
                                                await triggerWish(triggeredBy: "Retry Button")
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Try Again")
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 20)
                                
                            } else if let event = viewModel.currentEvent {
                                // Success state - show event
                                EventPreviewCard(event: event, isLoadingDetail: isLoadingFullEvent)
                                    .padding(.horizontal, 20)
                                    .onTapGesture {
                                        if networkMonitor.isConnected {
                                            loadFullEventAndShowDetail(eventId: event.id)
                                        } else {
                                            showNoConnectionAlert = true
                                        }
                                    }
                                
                            } else {
                                // Empty state (no event yet)
                                EmptyStateCard()
                                    .padding(.horizontal, 20)
                            }
                            
                            // MARK: - Wish Me Luck Button
                            WishMeLuckButton(
                                isLoading: viewModel.isLoading,
                                isConnected: networkMonitor.isConnected
                            ) {
                                if networkMonitor.isConnected {
                                    Task {
                                        await triggerWish(triggeredBy: "Button")
                                    }
                                } else {
                                    showNoConnectionAlert = true
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                            
                            // MARK: - NFC Scan Button
                            if showNFCButton {
                                Button {
                                    nfcService.startNFCSession()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "wave.3.right")
                                            .font(.title3)
                                        Text("Scan NFC Tag")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(Color("appBlue"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color("appBlue"), lineWidth: 2)
                                    )
                                }
                                .disabled(viewModel.isLoading || !networkMonitor.isConnected)
                                .opacity((viewModel.isLoading || !networkMonitor.isConnected) ? 0.5 : 1.0)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEventDetail) {
                if let fullEvent = fullEventForDetail {
                    EventDetailView(event: fullEvent)
                }
            }
            .alert("No Internet Connection", isPresented: $showNoConnectionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please check your internet connection and try again.")
            }
            .alert("NFC Error", isPresented: $showNFCError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(nfcErrorMessage)
            }
            .task {
                // Setup NFC callbacks
                nfcService.onNFCTagRead = {
                    Task { @MainActor in
                        await triggerWish(triggeredBy: "NFC")
                    }
                }
                
                nfcService.onError = { error in
                    nfcErrorMessage = error
                    showNFCError = true
                }
                
                // Load data
                if networkMonitor.isConnected {
                    await viewModel.calculateDaysSinceLastWished()
                    await viewModel.syncPendingUpdates()
                } else {
                    await viewModel.calculateDaysSinceLastWished()
                }
                
                startAccelerometerUpdates()
            }
            .onDisappear {
                stopAccelerometerUpdates()
                nfcService.stopNFCSession()
            }
            .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
                if newValue && !oldValue {
                    print("🌐 Network restored - syncing pending updates")
                    Task {
                        await viewModel.syncPendingUpdates()
                        await viewModel.calculateDaysSinceLastWished()
                    }
                }
            }
            .navigationDestination(isPresented: $showNews) {
                NewsView()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func getErrorIcon(for error: String) -> String {
        if error.contains("No internet connection") || error.contains("network") {
            return "wifi.slash"
        } else if error.contains("No authenticated user") || error.contains("authentication") {
            return "person.crop.circle.badge.exclamationmark"
        } else if error.contains("No events available") || error.contains("empty") {
            return "tray"
        } else {
            return "exclamationmark.triangle"
        }
    }
    
    private func getErrorHint(for error: String) -> String {
        if error.contains("No internet connection") || error.contains("network") {
            return "Please check your connection and try again"
        } else if error.contains("No authenticated user") || error.contains("authentication") {
            return "Please sign in to use this feature"
        } else if error.contains("No events available") || error.contains("empty") {
            return "Check back later or try shaking again"
        } else if error.contains("Failed to load") {
            return "We're having trouble reaching our servers"
        } else {
            return "Something went wrong. Please try again"
        }
    }
    
    // MARK: - Load Full Event and Show Detail
    private func loadFullEventAndShowDetail(eventId: String) {
        guard networkMonitor.isConnected else {
            showNoConnectionAlert = true
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
                                
                if let event = EventFactory.createEvent(from: document) {
                    print("✅ Successfully parsed event using EventFactory")
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
        
        var location: EventLocation? = nil
        if let locationData = data["location"] as? [String: Any] {
            location = EventLocation(
                address: locationData["address"] as? String ?? "",
                city: locationData["city"] as? String ?? "",
                coordinates: locationData["coordinates"] as? [Double] ?? [],
                type: locationData["type"] as? String ?? ""
            )
        }
        
        var schedule = EventSchedule(days: [], times: [])
        if let scheduleData = data["schedule"] as? [String: Any] {
            schedule = EventSchedule(
                days: scheduleData["days"] as? [String] ?? [],
                times: scheduleData["times"] as? [String] ?? []
            )
        }
        
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
        
        var stats = EventStats(popularity: 0,
                               rating: 0,
                               ratingList: [],
                               totalCompletions: 0)
        if let statsData = data["stats"] as? [String: Any] {
            stats = EventStats(
                popularity: statsData["popularity"] as? Int ?? 0,
                rating: statsData["rating"] as? Int ?? 0,
                ratingList: statsData["rating_list"] as? [Int?] ?? [],
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
        
        event.id = documentId
        
        return event
    }
    
    // MARK: - Trigger Wish (with source tracking)
    private func triggerWish(triggeredBy source: String = "Button") async {
        guard networkMonitor.isConnected else {
            showNoConnectionAlert = true
            return
        }
        
        print("🎯 Wish triggered by: \(source)")
        AnalyticsService.shared.logWishMeLuckUsed()
        
        // Log NFC-specific analytics if triggered by NFC
        if source == "NFC" {
            Analytics.logEvent("wish_me_luck_nfc", parameters: [
                "method": "nfc_tag"
            ])
        }
        
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
        
        guard networkMonitor.isConnected else {
            showNoConnectionAlert = true
            return
        }
        
        lastShakeTime = now
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            await triggerWish(triggeredBy: "Shake")
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
            Text("Shake your phone, scan NFC, or tap the button")
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
            
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(event.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
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
            
            Text("Shake, scan NFC, or tap the button below")
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
    let isConnected: Bool
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
            .background(isLoading ? Color.gray : (isConnected ? Color.appOcher : Color.gray))
            .cornerRadius(16)
        }
        .disabled(isLoading || !isConnected)
    }
}

// MARK: - Preview
struct WishMeLuckView_Previews: PreviewProvider {
    static var previews: some View {
        WishMeLuckView()
    }
}
