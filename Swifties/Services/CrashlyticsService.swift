//
//  CrashlyticsService.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//

// CrashlyticsService.swift
import Foundation
import FirebaseCrashlytics
import FirebaseAnalytics

final class CrashlyticsService {
    static let shared = CrashlyticsService()
    private init() {}


    func recordNonFatal(_ error: Error, platform: String = "ios", additionalInfo: [String: Any]? = nil) {
        let crashlytics = Crashlytics.crashlytics()
   
        crashlytics.setCustomValue(platform, forKey: "platform")
        if let info = additionalInfo {
            for (k, v) in info {
             
                crashlytics.setCustomValue(String(describing: v), forKey: k)
            }
        }

        crashlytics.record(error: error)

     
        Analytics.logEvent("app_exception", parameters: [
            "error_type": String(describing: type(of: error)),
            "platform": platform
        ])
    }

    func setUserId(_ uid: String) {
        Crashlytics.crashlytics().setUserID(uid)
    }
}
