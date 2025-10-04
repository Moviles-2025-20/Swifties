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
            try await Task.sleep(nanoseconds: 1_500_000_000)

            let snapshot = try await db.collection("events")
                .whereField("active", isEqualTo: true)
                .getDocuments()

            print("Eventos encontrados: \(snapshot.documents.count)")

    
            if let randomDoc = snapshot.documents.randomElement() {
                print("Documento elegido: \(randomDoc.documentID)")
                print("Data cruda: \(randomDoc.data())")
                
                if let event = try? randomDoc.data(as: Event.self) {
                    print("Parseado como Event")
                    currentEvent = WishMeLuckEvent.fromEvent(event)
                } else {
                    print("No se pudo parsear como Event, usando fallback")
                    let data = randomDoc.data()
                    let metadata = data["metadata"] as? [String: Any]
                    currentEvent = WishMeLuckEvent(
                        id: randomDoc.documentID,
                        title: data["title"] as? String ?? data["name"] as? String ?? "Untitled Event",
                        imageUrl: metadata?["image_url"] as? String
                               ?? metadata?["imageUrl"] as? String
                               ?? "",
                        description: data["description"] as? String ?? "No description available"
                    )
                }
            } else {
                print("No hay documentos con active = true")
                currentEvent = nil
            }

            try await updateLastWishedDate()
            await calculateDaysSinceLastWished()
        } catch {
            self.error = "Error getting event: \(error.localizedDescription)"
            print("Error Firestore: \(error)")
        }

        isLoading = false
    }


    
    // MARK: - Get Random Event
    func getRandomEvent(from events: [Event]) -> WishMeLuckEvent? {
        guard let randomEvent = events.randomElement() else { return nil }
        return WishMeLuckEvent.fromEvent(randomEvent)
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
