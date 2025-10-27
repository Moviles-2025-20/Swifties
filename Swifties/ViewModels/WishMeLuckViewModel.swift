import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class WishMeLuckViewModel: ObservableObject {
    @Published var currentEvent: WishMeLuckEvent?
    @Published var isLoading = false
    @Published var error: String?
    @Published var daysSinceLastWished: Int = 0
    
    private let db = Firestore.firestore(database: "default")

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
    
    // MARK: - Wish Me Luck with Smart Recommendations
    func wishMeLuck() async {
        print("🎯 === WISH ME LUCK STARTED ===")
        isLoading = true
        error = nil
        currentEvent = nil

        do {
            try await Task.sleep(nanoseconds: 1_500_000_000)

            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "WishMeLuck", code: 401,
                            userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
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
            }

            try await updateLastWishedDate()
            await calculateDaysSinceLastWished()
            
            print("🎯 === WISH ME LUCK COMPLETED ===\n")
            
        } catch {
            self.error = "Error getting event: \(error.localizedDescription)"
            print("❌ Error Firestore: \(error)")
            print("🎯 === WISH ME LUCK FAILED ===\n")
        }

        isLoading = false
    }
    
    // MARK: - Get Recommended Event
    private func getRecommendedEvent(
        userId: String,
        favoriteCategories: [String],
        lastEventId: String?,
        lastEventCategory: String?
    ) async throws -> WishMeLuckEvent? {
        
        print("🔍 Determining recommendation strategy...")
        
        // Case 1: User has a last event
        if let lastCategory = lastEventCategory, !lastCategory.isEmpty {
            print("📌 Case 1: User has last event category: '\(lastCategory)'")
            
            // Check if user has favorite categories
            if !favoriteCategories.isEmpty {
                print("   User has favorite categories: \(favoriteCategories)")
                
                // Get categories excluding the last one
                let availableCategories = favoriteCategories.filter { $0 != lastCategory }
                print("   Available categories (excluding last): \(availableCategories)")
                
                // If there are other favorite categories, pick from them
                if !availableCategories.isEmpty {
                    print("   👀 Strategy: Pick from available favorite categories")
                    return try await getRandomEventFromCategories(
                        categories: availableCategories,
                        excludeEventId: lastEventId
                    )
                } else {
                    // All favorite categories match the last category
                    // Pick from any category EXCEPT the last one
                    print("   ⚠️ All favorites match last category")
                    print("   👀 Strategy: Pick from ANY category except '\(lastCategory)'")
                    return try await getRandomEventExcludingCategory(
                        excludeCategory: lastCategory,
                        excludeEventId: lastEventId
                    )
                }
            } else {
                // No favorite categories defined
                // Pick from any category except the last one
                print("   ⚠️ No favorite categories defined")
                print("   👀 Strategy: Pick from ANY category except '\(lastCategory)'")
                return try await getRandomEventExcludingCategory(
                    excludeCategory: lastCategory,
                    excludeEventId: lastEventId
                )
            }
        }
        
        // Case 2: User has no last event
        else {
            print("📌 Case 2: User has NO last event")
            
            // If user has favorite categories, pick from them
            if !favoriteCategories.isEmpty {
                print("   User has favorite categories: \(favoriteCategories)")
                print("   👀 Strategy: Pick from favorite categories")
                return try await getRandomEventFromCategories(
                    categories: favoriteCategories,
                    excludeEventId: nil
                )
            } else {
                // No preferences at all, pick any random event
                print("   ⚠️ No preferences defined")
                print("   👀 Strategy: Pick ANY random event")
                return try await getRandomEvent(excludeEventId: nil)
            }
        }
    }
    
    // MARK: - Get Random Event from Specific Categories
    private func getRandomEventFromCategories(
        categories: [String],
        excludeEventId: String?
    ) async throws -> WishMeLuckEvent? {
        
        print("🎲 Getting random event from categories: \(categories)")
        
        // Pick a random category
        guard let randomCategory = categories.randomElement() else {
            print("   ⚠️ No categories available, falling back to any event")
            return try await getRandomEvent(excludeEventId: excludeEventId)
        }
        
        print("   Selected category: '\(randomCategory)'")
        
        // Query events from that category
        let query = db.collection("events")
            .whereField("active", isEqualTo: true)
            .whereField("category", isEqualTo: randomCategory)
        
        let snapshot = try await query.getDocuments()
        print("   Found \(snapshot.documents.count) events in category '\(randomCategory)'")
        
        // Filter out the last event if needed
        var documents = snapshot.documents
        if let excludeId = excludeEventId {
            documents = documents.filter { $0.documentID != excludeId }
            print("   Filtered out last event, now \(documents.count) events available")
        }
        
        // If no events found in this category, fallback to any event
        if documents.isEmpty {
            print("   ⚠️ No events available in category, falling back to any event")
            return try await getRandomEvent(excludeEventId: excludeEventId)
        }
        
        // Pick random event
        print("   ✅ Selecting random event from \(documents.count) options")
        return parseEventDocument(documents.randomElement())
    }
    
    // MARK: - Get Random Event Excluding Category
    private func getRandomEventExcludingCategory(
        excludeCategory: String,
        excludeEventId: String?
    ) async throws -> WishMeLuckEvent? {
        
        print("🚫 Getting random event EXCLUDING category: '\(excludeCategory)'")
        
        // Get all active events
        let snapshot = try await db.collection("events")
            .whereField("active", isEqualTo: true)
            .getDocuments()
        
        print("   Total active events: \(snapshot.documents.count)")
        
        // Filter by category and event ID
        var documents = snapshot.documents.filter { doc in
            let category = doc.data()["category"] as? String ?? ""
            return category != excludeCategory
        }
        
        print("   Events after excluding category '\(excludeCategory)': \(documents.count)")
        
        if let excludeId = excludeEventId {
            documents = documents.filter { $0.documentID != excludeId }
            print("   Events after excluding last event ID: \(documents.count)")
        }
        
        // Debug: Print categories of available events
        let availableCategories = Set(documents.compactMap { doc in
            doc.data()["category"] as? String
        })
        print("   Available categories: \(Array(availableCategories))")
        
        // If no events found, fallback to any event (shouldn't happen normally)
        if documents.isEmpty {
            print("   ⚠️ No events available, falling back to any event")
            return try await getRandomEvent(excludeEventId: excludeEventId)
        }
        
        print("   ✅ Selecting random event from \(documents.count) options")
        return parseEventDocument(documents.randomElement())
    }
    
    // MARK: - Get Random Event (Fallback)
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
    
    // MARK: - Parse Event Document (CORREGIDO)
    private func parseEventDocument(_ document: QueryDocumentSnapshot?) -> WishMeLuckEvent? {
        guard let doc = document else {
            print("   ⚠️ No document to parse")
            return nil
        }
        
        print("   📝 Parsing event document ID: \(doc.documentID)")
        
        // Usar EventFactory si existe, si no, parsing manual
        if let event = EventFactory.createEvent(from: doc) {
            let wishMeLuckEvent = WishMeLuckEvent.fromEvent(event)
            print("   ✅ Parsed using EventFactory")
            return wishMeLuckEvent
        } else {
            // Fallback a parsing manual
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
    
    // MARK: - Update User's Last Event
    // Note: This should only be called when user ACTUALLY ATTENDS the event
    // Not when they just get a recommendation
    func markEventAsAttended(eventId: String) async throws {
        print("✅ Marking event as attended: \(eventId)")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WishMeLuck", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let userRef = db.collection("users").document(userId)
        
        // Get the event document to find its category
        let eventDoc = try await db.collection("events").document(eventId).getDocument()
        let eventCategory = eventDoc.data()?["category"] as? String ?? ""
        
        print("   - Event Category: \(eventCategory)")
        
        try await userRef.updateData([
            "last_event": eventId,
            "event_last_category": eventCategory,
            "last_event_time": Timestamp(date: Date())
        ])
        
        print("   ✅ User last event updated")
    }
    
    // MARK: - Update Last Wished Date
    private func updateLastWishedDate() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WishMeLuck", code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "stats.last_wish_me_luck": Timestamp(date: Date())
        ])
        
        print("📅 Last wished date updated")
    }
    
    // MARK: - Calculate Days Since Last Wished
    func calculateDaysSinceLastWished() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            daysSinceLastWished = 0
            return
        }
        
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            guard let data = userDoc.data(),
                  let stats = data["stats"] as? [String: Any],
                  let lastWishTimestamp = stats["last_wish_me_luck"] as? Timestamp else {
                try await updateLastWishedDate()
                daysSinceLastWished = 0
                print("📅 No previous wish date found, setting to 0")
                return
            }
            
            let lastWishDate = lastWishTimestamp.dateValue()
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: lastWishDate, to: now)
            
            daysSinceLastWished = components.day ?? 0
            print("📅 Days since last wished: \(daysSinceLastWished)")
        } catch {
            print("❌ Error calculating days since last wished: \(error)")
            daysSinceLastWished = 0
        }
    }
    
    // MARK: - Clear Event
    func clearEvent() {
        print("🗑️ Clearing current event")
        currentEvent = nil
        error = nil
    }
}
