//
//  WishMeLuckViewModel.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 4/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import FirebaseCore

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
    
    // MARK: - Wish Me Luck
    func wishMeLuck() async {
        isLoading = true
        error = nil
        currentEvent = nil
        
        do {
            // Simulate shake/animation delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Get random event
            let event = try await getRandomEvent()
            currentEvent = event
            
            // Update last wished date
            try await updateLastWishedDate()
            
            // Recalculate days since last wished
            await calculateDaysSinceLastWished()
            
            error = nil
        } catch {
            self.error = "Error getting event: \(error.localizedDescription)"
            currentEvent = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Get Random Event
    private func getRandomEvent() async throws -> WishMeLuckEvent {
        let snapshot = try await db.collection("events")
            .whereField("activetrue", isEqualTo: true)
            .getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            throw NSError(domain: "WishMeLuck", code: 404, userInfo: [NSLocalizedDescriptionKey: "No events available"])
        }
        
        // Get random event
        guard let randomDoc = snapshot.documents.randomElement() else {
            throw NSError(domain: "WishMeLuck", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not select random event"])
        }
        
        // Try to decode as Event first
        if let event = try? randomDoc.data(as: Event.self) {
            return WishMeLuckEvent.fromEvent(event)
        }
        
        // Fallback: manual parsing
        let data = randomDoc.data()
        let id = randomDoc.documentID
        let title = data["title"] as? String ?? data["name"] as? String ?? "Untitled Event"
        let description = data["description"] as? String ?? "No description available"
        
        var imageUrl = ""
        if let metadata = data["metadata"] as? [String: Any],
           let url = metadata["image_url"] as? String {
            imageUrl = url
        }
        
        return WishMeLuckEvent(
            id: id,
            title: title,
            imageUrl: imageUrl,
            description: description
        )
    }
    
    // MARK: - Update Last Wished Date
    private func updateLastWishedDate() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WishMeLuck", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "stats.last_wish_me_luck": Timestamp(date: Date())
        ])
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
                // First time using wish me luck
                try await updateLastWishedDate()
                daysSinceLastWished = 0
                return
            }
            
            let lastWishDate = lastWishTimestamp.dateValue()
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: lastWishDate, to: now)
            
            daysSinceLastWished = components.day ?? 0
        } catch {
            print("Error calculating days since last wished: \(error)")
            daysSinceLastWished = 0
        }
    }
    
    // MARK: - Clear Event
    func clearEvent() {
        currentEvent = nil
        error = nil
    }
}
