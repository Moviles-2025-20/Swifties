//
//  WishMeLuckNetworkService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class WishMeLuckNetworkService {
    static let shared = WishMeLuckNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    private init() {}
    
    // MARK: - Fetch Days Since Last Wished from Network
    
    func fetchDaysSinceLastWished(userId: String, completion: @escaping (Result<(days: Int, lastWishedDate: Date?), Error>) -> Void) {
        print("🌐 Fetching days since last wished from network...")
        
        db.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                let error = NSError(domain: "WishMeLuck", code: 404,
                                  userInfo: [NSLocalizedDescriptionKey: "User data not found"])
                completion(.failure(error))
                return
            }
            
            // Extract last wish timestamp
            var lastWishDate: Date?
            var daysSince = 0
            
            if let stats = data["stats"] as? [String: Any],
               let lastWishTimestamp = stats["last_wish_me_luck"] as? Timestamp {
                lastWishDate = lastWishTimestamp.dateValue()
                
                let now = Date()
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: lastWishDate!, to: now)
                daysSince = components.day ?? 0
                
                print("✅ Network fetch completed - \(daysSince) days since last wished")
            } else {
                print("⚠️ No previous wish date found in network")
            }
            
            completion(.success((days: daysSince, lastWishedDate: lastWishDate)))
        }
    }
    
    // MARK: - Update Last Wished Date
    
    func updateLastWishedDate(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 Updating last wished date on network...")
        
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "stats.last_wish_me_luck": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("❌ Error updating last wished date: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ Last wished date updated on network")
                completion(.success(()))
            }
        }
    }
}
