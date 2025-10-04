//
//  UserActivity.swift
//  Swifties
//
//  Created by Imac  on 4/10/25.
//
import Foundation

struct UserActivity: Identifiable, Codable {
    var id: String?
    var eventId: String
    var rating: Int?
    var source: String
    var time: Date
    var timeOfDay: String?
    var type: String
    var userId: String
    var withFriends: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case rating
        case source
        case time
        case timeOfDay = "time_of_day"
        case type
        case userId = "user_id"
        case withFriends = "with_friends"
    }
}
