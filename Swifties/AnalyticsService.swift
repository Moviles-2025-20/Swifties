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

class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

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

    func logScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenName
        ])
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
}
func activarFirebase() {
    Analytics.setAnalyticsCollectionEnabled(true)
}
