//
//  FreeTimeSlot.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

import Foundation

struct FreeTimeSlot: Identifiable {
    let id: String
    let day: String
    let start: String
    let end: String
    
    // Initializer for Firebase/JSON (generates automatic UUID)
    init(data: [String: Any]) {
        self.id = UUID().uuidString
        self.day = data["day"] as? String ?? ""
        self.start = data["start"] as? String ?? ""
        self.end = data["end"] as? String ?? ""
    }
    
    // Initializer for SQLite (uses explicit id)
    init(id: String, day: String, start: String, end: String) {
        self.id = id
        self.day = day
        self.start = start
        self.end = end
    }
}
