//
//  AnalyticsService.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

import Foundation
import FirebaseAnalytics

enum DiscoveryMethod: String {
    case wishMeLuck = "wish_me_luck"
    case manualBrowse = "manual_browse"
}

enum MapViewSource: String {
    case eventList = "event_list_toggle"
    case directAccess = "direct_access"
    case deepLink = "deep_link"
}

class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {activarFirebase()}
    
    func logDiscoveryMethod(_ method: DiscoveryMethod) {
        Analytics.logEvent("activity_discovery_method", parameters: [
            "method": method.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func logActivitySelection(activityId: String, discoveryMethod: DiscoveryMethod) {
        Analytics.logEvent("activity_selected", parameters: [
            "activity_id": activityId,
            "discovery_method": discoveryMethod.rawValue
        ])
    }
    
    func logWishMeLuckUsed() {
        Analytics.logEvent("wish_me_luck_used", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func logOutdoorIndoorPreference(_ percentage: Int) {
        Analytics.logEvent("outdoor_indoor_preference", parameters: [
            "percentage": percentage
        ])
    }
    
    func setUserId(_ userId: String) {
        Analytics.setUserID(userId)
    }
    
    func logError(_ error: Error, platform: String) {
        Analytics.logEvent("app_exception", parameters: [
            "error_type": String(describing: type(of: error)),
            "platform": platform
        ])
    }
    
    func logCheckIn(activityId: String, category: String) {
        Analytics.logEvent("activity_check_in", parameters: [
            "activity_id": activityId,
            "category": category
        ])
    }
    
    // Log when the user requests directions to an event
    func logDirectionRequest(eventId: String, eventName: String) {
        Analytics.logEvent("event_direction_requested", parameters: [
            "event_id": eventId,
            "event_name": eventName,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Map Feature Analytics
    
    /// Logs when the user opens/views the campus map
    /// Use this to track map feature usage frequency
    func logMapViewOpened(source: MapViewSource = .eventList, eventCount: Int = 0) {
        Analytics.logEvent("map_view_opened", parameters: [
            "source": source.rawValue,
            "event_count": eventCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Logs when the user closes/exits the map view
    /// Combine with logMapViewOpened to calculate session duration
    func logMapViewClosed(durationSeconds: TimeInterval) {
        Analytics.logEvent("map_view_closed", parameters: [
            "duration_seconds": durationSeconds,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Logs interactions within the map (optional, for deeper insights)
    func logMapInteraction(action: String, eventId: String? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let eventId = eventId {
            parameters["event_id"] = eventId
        }
        Analytics.logEvent("map_interaction", parameters: parameters)
    }
    
    
    // MARK: - Mood Quiz Analytics
    
    /// Logs when the user opens/starts the Mood Quiz screen
    func logMoodQuizOpened(source: String = "home") {
        Analytics.logEvent("mood_quiz_opened", parameters: [
            "source": source,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Logs when the user answers the first question (quiz started)
    func logMoodQuizStarted() {
        Analytics.logEvent("mood_quiz_started", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Logs when the user completes all quiz questions and clicks Finish
    func logMoodQuizCompleted(resultCategory: String, totalScore: Int, isTied: Bool) {
        Analytics.logEvent("mood_quiz_completed", parameters: [
            "result_category": resultCategory,
            "total_score": totalScore,
            "is_tied": isTied,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Called when a News item is liked
    func logEventSelected(eventId: String, category: String) {
        Analytics.logEvent("event_category_liked", parameters: [
            "event_id": eventId,
            "category": category,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Called when event ratings are sent to Firebase to be compared
    func logEventRatingsSnapshot(eventId: String, eventName: String, average: Double, total: Int) async {
        Analytics.logEvent("event_ratings_snapshot", parameters: [
            "event_id": eventId,
            "event_name": eventName,
            "average_rating": average,
            "ratings_total": total,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}

func activarFirebase() {
    Analytics.setAnalyticsCollectionEnabled(true)
}
