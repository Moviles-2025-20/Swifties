//
//  WeeklyChallengeUserDefaultsService.swift
//  Swifties
//
//  Layer 2A: UserDefaults Storage for Weekly Challenge (12 hours TTL)
//

import Foundation

class WeeklyChallengeUserDefaultsService {
    static let shared = WeeklyChallengeUserDefaultsService()
    
    private let userDefaults = UserDefaults.standard
    private let eventKey = "weekly_challenge_event"
    private let hasAttendedKey = "weekly_challenge_attended"
    private let totalKey = "weekly_challenge_total"
    private let chartDataKey = "weekly_challenge_chart"
    private let timestampKey = "weekly_challenge_timestamp"
    private let weekIdKey = "weekly_challenge_week_id"
    private let storageExpirationHours = 12.0 // 12 hours like UserEvents
    
    // Lazy encoder/decoder for efficiency
    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private init() {}
    
    // MARK: - Save
    
    func saveChallenge(userId: String, event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData]) {
        let weekId = Date().weekIdentifier()
        
        // Convert Event to CodableEvent
        var eventData: Data?
        if let event = event {
            let codableEvent = event.toCodable()
            eventData = try? jsonEncoder.encode(codableEvent)
        }
        
        // Encode chart data
        let chartDataEncoded = try? jsonEncoder.encode(chartData)
        
        // Save with userId prefix
        let eventKey = "\(self.eventKey)_\(userId)"
        let hasAttendedKey = "\(self.hasAttendedKey)_\(userId)"
        let totalKey = "\(self.totalKey)_\(userId)"
        let chartDataKey = "\(self.chartDataKey)_\(userId)"
        let timestampKey = "\(self.timestampKey)_\(userId)"
        let weekIdKey = "\(self.weekIdKey)_\(userId)"
        
        userDefaults.set(eventData, forKey: eventKey)
        userDefaults.set(hasAttended, forKey: hasAttendedKey)
        userDefaults.set(totalChallenges, forKey: totalKey)
        userDefaults.set(chartDataEncoded, forKey: chartDataKey)
        userDefaults.set(Date(), forKey: timestampKey)
        userDefaults.set(weekId, forKey: weekIdKey)
        
        print("💾 Weekly Challenge saved to UserDefaults")
        print("   - Week ID: \(weekId)")
        print("   - Event: \(event?.name ?? "nil")")
        print("   - Has Attended: \(hasAttended)")
        print("   - Total: \(totalChallenges)")
    }
    
    // MARK: - Load
    
    func loadChallenge(userId: String) -> (event: Event?, hasAttended: Bool, totalChallenges: Int, chartData: [WeeklyChallengeChartData])? {
        let currentWeekId = Date().weekIdentifier()
        
        let eventKey = "\(self.eventKey)_\(userId)"
        let hasAttendedKey = "\(self.hasAttendedKey)_\(userId)"
        let totalKey = "\(self.totalKey)_\(userId)"
        let chartDataKey = "\(self.chartDataKey)_\(userId)"
        let timestampKey = "\(self.timestampKey)_\(userId)"
        let weekIdKey = "\(self.weekIdKey)_\(userId)"
        
        // Check week ID
        guard let storedWeekId = userDefaults.string(forKey: weekIdKey) else {
            print("❌ No week ID found in UserDefaults")
            return nil
        }
        
        if storedWeekId != currentWeekId {
            print("⚠️ Stored data is from different week: \(storedWeekId) vs \(currentWeekId)")
            clearStorage(userId: userId)
            return nil
        }
        
        // Check timestamp expiration
        guard let timestamp = userDefaults.object(forKey: timestampKey) as? Date else {
            print("❌ No timestamp found")
            return nil
        }
        
        let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
        print("📦 UserDefaults storage age: \(String(format: "%.1f", hoursElapsed)) hours")
        
        if hoursElapsed > storageExpirationHours {
            print("⏰ UserDefaults data expired")
            clearStorage(userId: userId)
            return nil
        }
        
        // Load data
        let hasAttended = userDefaults.bool(forKey: hasAttendedKey)
        let totalChallenges = userDefaults.integer(forKey: totalKey)
        
        // Decode event
        var event: Event?
        if let eventData = userDefaults.data(forKey: eventKey) {
            if let codableEvent = try? jsonDecoder.decode(CodableEvent.self, from: eventData) {
                event = Event.from(codable: codableEvent)
            }
        }
        
        // Decode chart data
        var chartData: [WeeklyChallengeChartData] = []
        if let chartDataEncoded = userDefaults.data(forKey: chartDataKey) {
            chartData = (try? jsonDecoder.decode([WeeklyChallengeChartData].self, from: chartDataEncoded)) ?? []
        }
        
        print("✅ Weekly Challenge loaded from UserDefaults")
        print("   - Event: \(event?.name ?? "nil")")
        print("   - Has Attended: \(hasAttended)")
        print("   - Total: \(totalChallenges)")
        print("   - Chart Points: \(chartData.count)")
        
        return (event: event, hasAttended: hasAttended, totalChallenges: totalChallenges, chartData: chartData)
    }
    
    // MARK: - Delete
    
    func clearStorage(userId: String) {
        let eventKey = "\(self.eventKey)_\(userId)"
        let hasAttendedKey = "\(self.hasAttendedKey)_\(userId)"
        let totalKey = "\(self.totalKey)_\(userId)"
        let chartDataKey = "\(self.chartDataKey)_\(userId)"
        let timestampKey = "\(self.timestampKey)_\(userId)"
        let weekIdKey = "\(self.weekIdKey)_\(userId)"
        
        userDefaults.removeObject(forKey: eventKey)
        userDefaults.removeObject(forKey: hasAttendedKey)
        userDefaults.removeObject(forKey: totalKey)
        userDefaults.removeObject(forKey: chartDataKey)
        userDefaults.removeObject(forKey: timestampKey)
        userDefaults.removeObject(forKey: weekIdKey)
        
        print("🗑️ Weekly Challenge UserDefaults cleared for user: \(userId)")
    }
    
    // MARK: - Debug
    
    func debugStorage(userId: String) {
        let timestampKey = "\(self.timestampKey)_\(userId)"
        let weekIdKey = "\(self.weekIdKey)_\(userId)"
        
        print("\n=== DEBUG WEEKLY CHALLENGE USERDEFAULTS ===")
        
        if let timestamp = userDefaults.object(forKey: timestampKey) as? Date {
            let hoursElapsed = Date().timeIntervalSince(timestamp) / 3600
            let storedWeekId = userDefaults.string(forKey: weekIdKey) ?? "unknown"
            let currentWeekId = Date().weekIdentifier()
            
            print("Timestamp: \(timestamp)")
            print("Age: \(String(format: "%.1f", hoursElapsed)) hours")
            print("Stored Week: \(storedWeekId)")
            print("Current Week: \(currentWeekId)")
            print("Is Current Week: \(storedWeekId == currentWeekId ? "YES ✅" : "NO ❌")")
            print("Is Expired: \(hoursElapsed > storageExpirationHours ? "YES ⏰" : "NO ✅")")
        } else {
            print("No data found in UserDefaults")
        }
        
        print("==========================================\n")
    }
}
