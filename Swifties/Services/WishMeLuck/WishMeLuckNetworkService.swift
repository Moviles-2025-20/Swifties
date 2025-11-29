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
        
        // Use background queue for network request (doesn't block UI)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.db.collection("users").document(userId).getDocument { document, error in
                // Process response on background queue
                DispatchQueue.global(qos: .utility).async {
                    if let error = error {
                        print("❌ Network error: \(error.localizedDescription)")
                        // Return to main thread for completion
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        return
                    }
                    
                    guard let document = document, document.exists,
                          let data = document.data() else {
                        let error = NSError(domain: "WishMeLuck", code: 404,
                                          userInfo: [NSLocalizedDescriptionKey: "User data not found"])
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        return
                    }
                    
                    // Heavy computation: Calculate days difference
                    var lastWishDate: Date?
                    var daysSince = 0
                    
                    if let stats = data["stats"] as? [String: Any],
                       let lastWishTimestamp = stats["last_wish_me_luck"] as? Timestamp {
                        
                        let lastWishDateValue = lastWishTimestamp.dateValue()
                        lastWishDate = lastWishDateValue
                        
                        let now = Date()
                        let calendar = Calendar.current
                        
                        let components = calendar.dateComponents([.day], from: lastWishDateValue, to: now)
                        daysSince = max(0, components.day ?? 0)
                        
                        print("✅ Network fetch completed - \(daysSince) days since last wished")
                    } else {
                        print("⚠️ No previous wish date found in network")
                    }
                    
                    // Return result on main thread
                    DispatchQueue.main.async {
                        completion(.success((days: daysSince, lastWishedDate: lastWishDate)))
                    }
                }
            }
        }
    }
    
    // MARK: - Update Last Wished Date
    
    func updateLastWishedDate(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔵 Updating last wished date on network...")
        
        // Background queue for network write operation
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let userRef = self.db.collection("users").document(userId)
            
            userRef.updateData([
                "stats.last_wish_me_luck": Timestamp(date: Date())
            ]) { error in
                // Return to main thread for completion
                DispatchQueue.main.async {
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
    }
}
