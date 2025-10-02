//
//  Event.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

import Foundation

struct Event: Identifiable {
    var id: String             
    var name: String
    var description: String
    var category: String
    var active: Bool
    var title: String
    var eventType: [String]
}
