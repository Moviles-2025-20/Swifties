//
//  User.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 1/10/25.
//

import Foundation
import FirebaseAuth

struct UserModel{
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    let providerId: String
    
    init(uid: String,
         email: String? = nil,
         displayName: String? = nil,
         photoURL: String? = nil,
         providerId: String) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.providerId = providerId
    }
    
    // Factory method to create UserModel from Firebase User
    static func fromFirebase(_ firebaseUser: User, providerId: String) -> UserModel {
        return UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL?.absoluteString,
            providerId: providerId
        )
    }
}

enum AuthProviderType {
    case google
    case github
    case facebook
}
