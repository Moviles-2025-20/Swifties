//
//  UserProfile.swift
//  Swifties
//
//  Created by Juan Esteban Vásquez on 01/10/25.
//

import Foundation

/// Domain model representing a user's profile in the app.
/// This is the Model in MVVM and should remain a simple data container.
struct UserProfile: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let avatar_url: String?
    let major: String
    let age: Int
    let indoor_outdoor_score: String
    let preferences: [String]
}
