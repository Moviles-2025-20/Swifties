//
//  ProfileViewModel.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 1/10/25.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: UserProfileRepository

    init(repository: UserProfileRepository? = nil) {
        if let repository {
            self.repository = repository
        } else {
            self.repository = FirebaseUserProfileRepository()
        }
    }

    func loadProfile(userID: String? = Auth.auth().currentUser?.uid) {
        guard let uid = userID else {
            self.errorMessage = "You are not logged in."
            self.isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loaded = try await repository.loadProfile(userID: uid)
                self.profile = loaded
                self.isLoading = false
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

