//
//  EventDetailViewModel.swift
//  Swifties
//
//

import Foundation
import FirebaseFirestore
import Combine

class EventDetailViewModel: ObservableObject {
    @Published var event: Event?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var comments: [Comment] = []
    
    // Derived ratings from loaded comments
    @Published var averageRating: Double = 0.0
    // Index 0 -> 1-star, ..., Index 4 -> 5-star counts
    @Published var ratingCounts: [Int] = [0, 0, 0, 0, 0]

    // Convenience: total number of valid ratings
    var totalRatings: Int { ratingCounts.reduce(0, +) }
    let db = Firestore.firestore(database: "default")
    private var commentsListener: ListenerRegistration? = nil
    
    init(event: Event) {
        self.event = event
        // Configure Firestore settings
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true
        firestore.settings = settings
    }

    // MARK: - Real-time Comments Listener
    func startListeningForComments(forEventId: String?) {
        // If we don't have an event id, exit as requested
        guard let forEventId = forEventId, !forEventId.isEmpty else { return }

        // Remove any existing listener to avoid duplicates
        commentsListener?.remove()

        commentsListener = db.collection("comments")
            .whereField("event_id", isEqualTo: forEventId)
            .order(by: "created", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening for comments: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { 
                        self.comments = [] 
                    }
                    return
                }
                let parsed: [Comment] = docs.compactMap { doc in
                    try? doc.data(as: Comment.self)
                }
                DispatchQueue.main.async {
                    self.comments = parsed
                    self.recalculateRatings()

                    // Update event using secondary variable to trigger @Published
                    var updatedEvent = self.event
                    updatedEvent?.stats.ratingList = self.comments.compactMap(\.rating)
                    self.event = updatedEvent
                }
            }
    }

    func stopListeningForComments() {
        commentsListener?.remove()
        commentsListener = nil
    }
    
    // MARK: - Ratings aggregation
    private func recalculateRatings() {
        // Filter to valid ratings 1...5
        let validComments: [Comment] = comments.filter { comment in
            if let rating = comment.rating { return (1...5).contains(rating) }
            return false
        }

        // Reset counts
        var counts = [0, 0, 0, 0, 0]
        for comment in validComments {
            if let rating = comment.rating, (1...5).contains(rating) {
                counts[rating - 1] += 1
            }
        }

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

        // Publish on main thread
        DispatchQueue.main.async {
            self.ratingCounts = counts
            self.averageRating = avg
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
