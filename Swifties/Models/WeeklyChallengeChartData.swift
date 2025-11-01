//
//  WeeklyChallengeChartData.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

import Foundation

struct WeeklyChallengeChartData: Identifiable, Codable {
    let id: UUID
    let label: String
    let count: Int
    
    init(label: String, count: Int) {
        self.id = UUID()
        self.label = label
        self.count = count
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, label, count
    }
}
