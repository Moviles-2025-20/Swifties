import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class WishMeLuckViewModel: ObservableObject {
    @Published var currentEvent: WishMeLuckEvent?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var daysSinceLastWished: Int = 0
    @Published var dataSource: DataSource = .none
    @Published var isRefreshing = false
    @Published var hasPendingWishUpdate = false
    
    enum DataSource {
        case none
        case memoryCache
        case realmStorage
        case network
    }
    
    private let db = Firestore.firestore(database: "default")
    
    // Three-layer cache services
    private let cacheService = WishMeLuckCacheService.shared
    private let storageService = WishMeLuckStorageService.shared
    private let networkService = WishMeLuckNetworkService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    // MARK: - Motivational Messages
    func getMotivationalMessage() -> String {
        guard let event = currentEvent else { return "" }
        
        let messages = [
            "The stars align for \"\(event.title)\"! ✨",
            "Destiny says \"\(event.title)\" is for you! 🍀",
            "\"\(event.title)\" is waiting for you! 🌟",
            "Good luck with \"\(event.title)\"! 💫"
        ]
        
        return messages.randomElement() ?? messages[0]
    }
    
    // MARK: - Calculate Days Since Last Wished (Three-Layer Cache)
    
    func calculateDaysSinceLastWished() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            daysSinceLastWished = 0
            dataSource = .none
            return
        }
        
        print("🚀 Loading days since last wished for user: \(userId)")
        
        // Layer 1: Try memory cache
        if let cached = await cacheService.getCachedDaysSinceLastWished(userId: userId) {
            self.daysSinceLastWished = cached.daysSinceLastWished
            self.dataSource = .memoryCache
            print("✅ Loaded from memory cache: \(cached.daysSinceLastWished) days")
            
            // Try to refresh in background if connected
            refreshDaysInBackground(userId: userId)
            return
        }
        
        // Layer 2: Try Realm storage
        if let stored = storageService.loadDaysSinceLastWished(userId: userId) {
            self.daysSinceLastWished = stored.days
            self.dataSource = .realmStorage
            
            // Cache in memory for next time
            await cacheService.cacheDaysSinceLastWished(
                userId: userId,
                days: stored.days,
                lastWishedDate: stored.lastWishedDate
            )
            
            print("✅ Loaded from Realm storage: \(stored.days) days")
            
            // Try to refresh in background if connected
            refreshDaysInBackground(userId: userId)
            return
        }
        
        // Layer 3: Fetch from network
        if networkMonitor.isConnected {
            await fetchDaysFromNetwork(userId: userId)
        } else {
            self.daysSinceLastWished = 0
            self.dataSource = .none
            print("❌ No connection and no local data")
        }
    }
    
    // FIX 1: Always resume continuation to prevent hanging
    private func fetchDaysFromNetwork(userId: String) async {
        await withCheckedContinuation { continuation in
            networkService.fetchDaysSinceLastWished(userId: userId) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    switch result {
                    case .success(let data):
                        self.daysSinceLastWished = data.days
                        self.dataSource = .network
                        
                        // Save to both cache layers
                        await self.cacheService.cacheDaysSinceLastWished(
                            userId: userId,
                            days: data.days,
                            lastWishedDate: data.lastWishedDate
                        )
                        
                        self.storageService.saveDaysSinceLastWished(
                            userId: userId,
                            days: data.days,
                            lastWishedDate: data.lastWishedDate
                        )
                        
                        print("✅ Loaded from network and cached: \(data.days) days")
                        
                    case .failure(let error):
                        print("❌ Network error: \(error.localizedDescription)")
                        self.daysSinceLastWished = 0
                        self.dataSource = .none
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // FIX 2: Use defer to ensure isRefreshing is always reset
    private func refreshDaysInBackground(userId: String) {
        guard networkMonitor.isConnected else { return }
        
        self.isRefreshing = true
        networkService.fetchDaysSinceLastWished(userId: userId) { [weak self] result in
            Task { @MainActor in
                defer {
                    self?.isRefreshing = false
                }
                
                guard let self = self else { return }
                
                if case .success(let data) = result {
                    // Check if data actually changed
                    let dataChanged = self.daysSinceLastWished != data.days
                    
                    // Update data
                    self.daysSinceLastWished = data.days
                    
                    // ALWAYS update data source to network after successful refresh
                    self.dataSource = .network
                    
                    // Update caches for next time
                    await self.cacheService.cacheDaysSinceLastWished(
                        userId: userId,
                        days: data.days,
                        lastWishedDate: data.lastWishedDate
                    )
                    
                    self.storageService.saveDaysSinceLastWished(
                        userId: userId,
                        days: data.days,
                        lastWishedDate: data.lastWishedDate
                    )
                    
                    let updateStatus = dataChanged ? "✅ Updated" : "✅ Confirmed"
                    print("\(updateStatus) days in background: \(data.days)")
                }
            }
        }
    }
    
    // MARK: - Wish Me Luck with Smart Recommendations (with Rollback)
    
    // FIX 3: Optimized rollback - removed unnecessary cache fetch
    func wishMeLuck() async {
        print("🎯 === WISH ME LUCK STARTED ===")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "No authenticated user"
            return
        }
        
        // Check connection before proceeding
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            return
        }
        
        isLoading = true
        errorMessage = nil
        currentEvent = nil

        // Store previous values for rollback
        let previousDays = daysSinceLastWished
        let previousDataSource = dataSource
        
        // Optimistically update UI
        print("💾 Optimistically updating to 0 days")
        daysSinceLastWished = 0
        
        do {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            print("👤 User ID: \(userId)")
            
            // Get user data
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else {
                throw NSError(domain: "WishMeLuck", code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "User data not found"])
            }
            
            print("📄 User data retrieved")
            
            // Extract user preferences
            let preferences = userData["preferences"] as? [String: Any] ?? [:]
            let favoriteCategories = preferences["favorite_categories"] as? [String] ?? []
            let lastEventId = userData["last_event"] as? String
            let lastEventCategory = userData["event_last_category"] as? String
            
            print("⚙️ User Preferences:")
            print("   - Favorite Categories: \(favoriteCategories)")
            print("   - Last Event ID: \(lastEventId ?? "None")")
            print("   - Last Event Category: \(lastEventCategory ?? "None")")
            
            // Get recommended event
            let event = try await getRecommendedEvent(
                userId: userId,
                favoriteCategories: favoriteCategories,
                lastEventId: lastEventId,
                lastEventCategory: lastEventCategory
            )
            
            if let event = event {
                print("✅ Event Selected:")
                print("   - ID: \(event.id)")
                print("   - Title: \(event.title)")
                print("   - Description: \(event.description)")
                currentEvent = event
            } else {
                print("❌ No event was selected")
                errorMessage = "No events available at this time"
                // Rollback on failure
                daysSinceLastWished = previousDays
                dataSource = previousDataSource
                throw NSError(domain: "WishMeLuck", code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "No events available"])
            }

            // Only update cache/storage after successful event selection
            try await updateLastWishedDateOnNetwork(userId: userId)
            
            // If network update succeeds, persist to cache
            await cacheService.cacheDaysSinceLastWished(
                userId: userId,
                days: 0,
                lastWishedDate: Date()
            )
            storageService.saveDaysSinceLastWished(
                userId: userId,
                days: 0,
                lastWishedDate: Date()
            )
            
            print("✅ Cache and storage updated after successful wish")
            print("🎯 === WISH ME LUCK COMPLETED ===\n")
            
        } catch {
            // Rollback on any error
            print("❌ Error occurred, rolling back...")
            daysSinceLastWished = previousDays
            dataSource = previousDataSource
            
            self.errorMessage = "Failed to load event: \(error.localizedDescription)"
            print("❌ Error Firestore: \(error)")
            print("🎯 === WISH ME LUCK FAILED ===\n")
        }

        isLoading = false
    }
    
    private func updateLastWishedDateOnNetwork(userId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            networkService.updateLastWishedDate(userId: userId) { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        print("✅ Last wished date updated on server")
                        self.hasPendingWishUpdate = false
                        continuation.resume()
                    case .failure(let error):
                        print("❌ Failed to update server: \(error.localizedDescription)")
                        self.hasPendingWishUpdate = true
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Pending Updates (call when network returns)
    
    func syncPendingUpdates() async {
        guard hasPendingWishUpdate,
              networkMonitor.isConnected,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        print("🔄 Syncing pending wish update...")
        do {
            try await updateLastWishedDateOnNetwork(userId: userId)
        } catch {
            print("❌ Sync failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get Recommended Event (existing code)
    
    private func getRecommendedEvent(
        userId: String,
        favoriteCategories: [String],
        lastEventId: String?,
        lastEventCategory: String?
    ) async throws -> WishMeLuckEvent? {
        
        print("🔍 Determining recommendation strategy...")
        
        if let lastCategory = lastEventCategory, !lastCategory.isEmpty {
            print("📌 Case 1: User has last event category: '\(lastCategory)'")
            
            if !favoriteCategories.isEmpty {
                print("   User has favorite categories: \(favoriteCategories)")
                
                let availableCategories = favoriteCategories.filter { $0 != lastCategory }
                print("   Available categories (excluding last): \(availableCategories)")
                
                if !availableCategories.isEmpty {
                    print("   👀 Strategy: Pick from available favorite categories")
                    return try await getRandomEventFromCategories(
                        categories: availableCategories,
                        excludeEventId: lastEventId
                    )
                } else {
                    print("   ⚠️ All favorites match last category")
                    print("   👀 Strategy: Pick from ANY category except '\(lastCategory)'")
                    return try await getRandomEventExcludingCategory(
                        excludeCategory: lastCategory,
                        excludeEventId: lastEventId
                    )
                }
            } else {
                print("   ⚠️ No favorite categories defined")
                print("   👀 Strategy: Pick from ANY category except '\(lastCategory)'")
                return try await getRandomEventExcludingCategory(
                    excludeCategory: lastCategory,
                    excludeEventId: lastEventId
                )
            }
        } else {
            print("📌 Case 2: User has NO last event")
            
            if !favoriteCategories.isEmpty {
                print("   User has favorite categories: \(favoriteCategories)")
                print("   👀 Strategy: Pick from favorite categories")
                return try await getRandomEventFromCategories(
                    categories: favoriteCategories,
                    excludeEventId: nil
                )
            } else {
                print("   ⚠️ No preferences defined")
                print("   👀 Strategy: Pick ANY random event")
                return try await getRandomEvent(excludeEventId: nil)
            }
        }
    }
    
    private func getRandomEventFromCategories(
        categories: [String],
        excludeEventId: String?
    ) async throws -> WishMeLuckEvent? {
        
        print("🎲 Getting random event from categories: \(categories)")
        
        guard let randomCategory = categories.randomElement() else {
            print("   ⚠️ No categories available, falling back to any event")
            return try await getRandomEvent(excludeEventId: excludeEventId)
        }
        
        print("   Selected category: '\(randomCategory)'")
        
        let query = db.collection("events")
            .whereField("active", isEqualTo: true)
            .whereField("category", isEqualTo: randomCategory)
        
        let snapshot = try await query.getDocuments()
        print("   Found \(snapshot.documents.count) events in category '\(randomCategory)'")
        
        var documents = snapshot.documents
        if let excludeId = excludeEventId {
            documents = documents.filter { $0.documentID != excludeId }
            print("   Filtered out last event, now \(documents.count) events available")
        }
        
        if documents.isEmpty {
            print("   ⚠️ No events available in category, falling back to any event")
            return try await getRandomEvent(excludeEventId: excludeEventId)
        }
        
        print("   ✅ Selecting random event from \(documents.count) options")
        return parseEventDocument(documents.randomElement())
    }
    
    private func getRandomEventExcludingCategory(
        excludeCategory: String,
        excludeEventId: String?
    ) async throws -> WishMeLuckEvent? {
        
        print("🚫 Getting random event EXCLUDING category: '\(excludeCategory)'")
        
        let snapshot = try await db.collection("events")
            .whereField("active", isEqualTo: true)
            .getDocuments()
        
        print("   Total active events: \(snapshot.documents.count)")
        
        var documents = snapshot.documents.filter { doc in
            let category = doc.data()["category"] as? String ?? ""
            return category != excludeCategory
        }
        
        print("   Events after excluding category '\(excludeCategory)': \(documents.count)")
        
        if let excludeId = excludeEventId {
            documents = documents.filter { $0.documentID != excludeId }
            print("   Events after excluding last event ID: \(documents.count)")
        }
        
        let availableCategories = Set(documents.compactMap { doc in
            doc.data()["category"] as? String
        })
        print("   Available categories: \(Array(availableCategories))")
        
        if documents.isEmpty {
            print("   ⚠️ No events available, falling back to any event")
            return try await getRandomEvent(excludeEventId: excludeEventId)
        }
        
        print("   ✅ Selecting random event from \(documents.count) options")
        return parseEventDocument(documents.randomElement())
    }
    
    private func getRandomEvent(excludeEventId: String?) async throws -> WishMeLuckEvent? {
        print("🎲 Getting any random event (fallback)")
        
        let snapshot = try await db.collection("events")
            .whereField("active", isEqualTo: true)
            .getDocuments()
        
        print("   Total active events: \(snapshot.documents.count)")
        
        var documents = snapshot.documents
        if let excludeId = excludeEventId {
            documents = documents.filter { $0.documentID != excludeId }
            print("   Events after excluding last event: \(documents.count)")
        }
        
        print("   ✅ Selecting random event from \(documents.count) options")
        return parseEventDocument(documents.randomElement())
    }
    
    private func parseEventDocument(_ document: QueryDocumentSnapshot?) -> WishMeLuckEvent? {
        guard let doc = document else {
            print("   ⚠️ No document to parse")
            return nil
        }
        
        print("   📝 Parsing event document ID: \(doc.documentID)")
        
        if let event = EventFactory.createEvent(from: doc) {
            let wishMeLuckEvent = WishMeLuckEvent.fromEvent(event)
            print("   ✅ Parsed using EventFactory")
            return wishMeLuckEvent
        } else {
            let data = doc.data()
            let category = data["category"] as? String ?? "Unknown"
            let title = data["title"] as? String ?? data["name"] as? String ?? "Untitled Event"
            
            print("   ✅ Parsed manually")
            print("      - Category: \(category)")
            print("      - Title: \(title)")
            
            return WishMeLuckEvent(
                id: doc.documentID,
                title: title,
                imageUrl: (data["metadata"] as? [String: Any])?["image_url"] as? String
                       ?? (data["metadata"] as? [String: Any])?["imageUrl"] as? String
                       ?? "",
                description: data["description"] as? String ?? "No description available"
            )
        }
    }
    
    // MARK: - Mark Event as Attended
    
    func markEventAsAttended(eventId: String) async throws {
        print("Marking event as attended: \(eventId)")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WishMeLuck", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let userRef = db.collection("users").document(userId)
        
        let eventDoc = try await db.collection("events").document(eventId).getDocument()
        let eventCategory = eventDoc.data()?["category"] as? String ?? ""
        
        print("   - Event Category: \(eventCategory)")
        
        try await userRef.updateData([
            "last_event": eventId,
            "event_last_category": eventCategory,
            "last_event_time": Timestamp(date: Date())
        ])
        
        print("   😊 User last event updated")
    }
    
    // MARK: - Cache Management
    
    func forceRefresh() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            await cacheService.clearCache(userId: userId)
        }
        storageService.deleteDaysSinceLastWished(userId: userId)
        Task {
            await calculateDaysSinceLastWished()
        }
    }
    
    func clearAllCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            await cacheService.clearCache(userId: userId)
        }
        storageService.deleteDaysSinceLastWished(userId: userId)
        daysSinceLastWished = 0
        dataSource = .none
    }
    
    func debugCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            await cacheService.debugCache(userId: userId)
        }
        storageService.debugStorage(userId: userId)
    }
    
    // MARK: - Clear Event
    
    func clearEvent() {
        print("Clearing current event")
        currentEvent = nil
        errorMessage = nil
    }
}
