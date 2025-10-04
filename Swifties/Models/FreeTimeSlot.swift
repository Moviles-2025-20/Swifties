
//
//  FreeTimeSlot.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

import Foundation

struct FreeTimeSlot: Identifiable {
    let id = UUID()
    let day: String
    let start: String
    let end: String
    
    init(data: [String: Any]) {
        self.day = data["day"] as? String ?? ""
        self.start = data["start"] as? String ?? ""
        self.end = data["end"] as? String ?? ""
    }
}
