import Foundation
import FirebaseAuth

final class ProfileNetworkService {
    static let shared = ProfileNetworkService()

    private let repository = UserProfileRepository()

    private init() {}

    func fetchProfile(completion: @escaping (Result<UserModel, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "ProfileNetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No logged in user"])) )
            return
        }

        Task {
            do {
                let profile = try await repository.loadProfile(userID: uid)
                completion(.success(profile))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
