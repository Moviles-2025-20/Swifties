//
//  CriteriaType+Extensions.swift
//  Swifties
//
//  Extensions for CriteriaType
//

import Foundation

extension CriteriaType {
    var detailedDescription: String {
        switch self {
        case .eventsAttended:
            return "Participate in events to unlock this badge"
        case .activitiesCompleted:
            return "Complete activities to earn this achievement"
        case .weeklyChallenges:
            return "Take part in weekly challenges"
        case .morningActivities:
            return "Complete activities in the morning"
        case .nightActivities:
            return "Complete activities at night"
        case .allDayWarrior:
            return "Complete activities in all time slots"
        case .firstComment:
            return "Leave your first comment"
        case .commentsLeft:
            return "Engage with the community by leaving comments"
        case .firstWeeklyChallenge:
            return "Participate in your first weekly challenge"
        }
    }
    
    var icon: String {
        switch self {
        case .eventsAttended:
            return "calendar.badge.checkmark"
        case .activitiesCompleted:
            return "checkmark.circle.fill"
        case .weeklyChallenges:
            return "trophy.fill"
        case .morningActivities:
            return "sunrise.fill"
        case .nightActivities:
            return "moon.stars.fill"
        case .allDayWarrior:
            return "clock.fill"
        case .firstComment:
            return "bubble.left.fill"
        case .commentsLeft:
            return "bubble.left.and.bubble.right.fill"
        case .firstWeeklyChallenge:
            return "star.circle.fill"
        }
    }
}
