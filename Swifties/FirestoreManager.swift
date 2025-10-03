//
//  FirestoreManager.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 2/10/25.
//

import Foundation
import FirebaseFirestore

/// Centralized Firestore database manager
/// Use this instead of calling Firestore.firestore() directly
class FirestoreManager {
    
    // Singleton instance
    static let shared = FirestoreManager()
    
    // Firestore database instance
    let db: Firestore
    
    private init() {
        // IMPORTANT: Explicitly specify "default" database
        // This prevents the "(default)" vs "default" naming issue
        self.db = Firestore.firestore(database: "default")
        
        // Configure settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    // Convenience method for common collections
    func usersCollection() -> CollectionReference {
        return db.collection("users")
    }
    
    func eventsCollection() -> CollectionReference {
        return db.collection("events")
    }
    
    func commentsCollection() -> CollectionReference {
        return db.collection("comments")
    }
    
    func userActivitiesCollection() -> CollectionReference {
        return db.collection("user_activities")
    }
}

// MARK: - Usage Example
/*
 Instead of:
     let db = Firestore.firestore()
     db.collection("users").getDocuments { ... }
 
 Use:
     FirestoreManager.shared.db.collection("users").getDocuments { ... }
     
 Or use convenience methods:
     FirestoreManager.shared.usersCollection().getDocuments { ... }
 */
