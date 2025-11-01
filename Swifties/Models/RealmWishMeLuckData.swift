//
//  RealmWishMeLuckData.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 30/10/25.
//

import Foundation
import RealmSwift

// MARK: - Realm Models

class RealmWishMeLuckData: Object {
    @Persisted(primaryKey: true) var userId: String
    @Persisted var daysSinceLastWished: Int = 0
    @Persisted var lastWishedDate: Date?
    @Persisted var lastUpdated: Date = Date()
    
    convenience init(userId: String, daysSinceLastWished: Int, lastWishedDate: Date?) {
        self.init()
        self.userId = userId
        self.daysSinceLastWished = daysSinceLastWished
        self.lastWishedDate = lastWishedDate
        self.lastUpdated = Date()
    }
}

// MARK: - Wish Me Luck Cache Model (In-Memory)
// FIX 5: Removed redundant isValid property

struct WishMeLuckCache {
    let daysSinceLastWished: Int
    let lastWishedDate: Date?
    let timestamp: Date
}

// MARK: - Conversion Extensions

extension RealmWishMeLuckData {
    func toCache() -> WishMeLuckCache {
        WishMeLuckCache(
            daysSinceLastWished: daysSinceLastWished,
            lastWishedDate: lastWishedDate,
            timestamp: lastUpdated
        )
    }
}
