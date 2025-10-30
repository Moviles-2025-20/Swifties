//
//  WeeklyChallengeModels.swift
//  Swifties
//
//  Models for Weekly Challenge with Realm support
//

import Foundation
import RealmSwift

// MARK: - Realm Models

class RealmWeeklyChallengeData: Object {
    @Persisted(primaryKey: true) var userId: String
    @Persisted var weekIdentifier: String // "2025-W44"
    @Persisted var eventData: Data? // Serialized Event
    @Persisted var hasAttended: Bool = false
    @Persisted var totalChallenges: Int = 0
    @Persisted var lastUpdated: Date = Date()
    @Persisted var chartData: List<RealmChartData>
    
    convenience init(userId: String, weekIdentifier: String, eventData: Data?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData]) {
        self.init()
        self.userId = userId
        self.weekIdentifier = weekIdentifier
        self.eventData = eventData
        self.hasAttended = hasAttended
        self.totalChallenges = totalChallenges
        self.lastUpdated = Date()
        
        let realmChartData = List<RealmChartData>()
        chartData.forEach { data in
            let realmData = RealmChartData()
            realmData.label = data.label
            realmData.count = data.count
            realmChartData.append(realmData)
        }
        self.chartData = realmChartData
    }
}

class RealmChartData: Object {
    @Persisted var label: String = ""
    @Persisted var count: Int = 0
}

// MARK: - Weekly Challenge Cache Model (In-Memory)

struct WeeklyChallengeCache {
    let event: Event?
    let hasAttended: Bool
    let totalChallenges: Int
    let chartData: [WeeklyChallengeChartData]
    let timestamp: Date
    
    var isValid: Bool {
        // Cache valid for 1 hour
        Date().timeIntervalSince(timestamp) < 3600
    }
}

// MARK: - Conversion Extensions

extension RealmWeeklyChallengeData {
    func toCache(event: Event?) -> WeeklyChallengeCache {
        WeeklyChallengeCache(
            event: event,
            hasAttended: hasAttended,
            totalChallenges: totalChallenges,
            chartData: chartData.map { WeeklyChallengeChartData(label: $0.label, count: $0.count) },
            timestamp: lastUpdated
        )
    }
}

// MARK: - Week Identifier Helper

extension Date {
    func weekIdentifier() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: self)
        let week = calendar.component(.weekOfYear, from: self)
        return "\(year)-W\(String(format: "%02d", week))"
    }
}
