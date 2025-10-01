//
//  UserProfile.swift
//  Swifties
//
//  Created by Juan Esteban Vásquez on 01/10/25.
//

import Foundation

/// Domain model representing a user's profile in the app.
/// This is the Model in MVVM and should remain a simple data container.
struct UserProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let imageURL: String?
    let major: String
    let age: Int
    let personality: String
    let preferences: [String]
}
