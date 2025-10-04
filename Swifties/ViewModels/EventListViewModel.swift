//
//  EventListViewModel.swift
//  Swifties
//
//  Created by Imac on 1/10/25.
//

import Foundation
import FirebaseFirestore
import Combine

class EventListViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let db = Firestore.firestore(database: "default")

    init() {
        // Initialize Firestore and configure settings
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        //settings.isPersistenceEnabled = true // optional offline cache
        firestore.settings = settings
    }

    func loadEvents() {
        isLoading = true
        errorMessage = nil

        db.collection("events").getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Error loading events: \(error.localizedDescription)"
                    print(self.errorMessage ?? "")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No events found"
                    return
                }

                
                self.events = documents.compactMap { EventFactory.createEvent(from: $0) }

                print("Events loaded: \(self.events.count)")
            }
        }
    }
    

    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
