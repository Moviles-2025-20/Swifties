import Foundation
import SQLite

final class ProfileStorageService {
    static let shared = ProfileStorageService()

    private let userDefaults = UserDefaults.standard
    private let timestampKey = "cached_profile_timestamp"
    private let storageExpirationHours: Double = 24

    // SQLite
    private var db: Connection?
    private let table = Table("profile")
    private let id = Expression<Int64>("id")
    private let payload = Expression<String>("payload")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let dbPath = "\(path)/profile.sqlite3"
            db = try Connection(dbPath)
            try db?.run(table.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(payload)
            })
        } catch {
            print("Profile DB setup error: \(error)")
        }
    }

    func saveProfile(_ profile: UserModel) {
        guard let db = db else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            let json = String(data: data, encoding: .utf8) ?? "{}"

            // Upsert single row with id = 1
            try db.transaction {
                try db.run(table.delete())
                try db.run(table.insert(id <- 1, payload <- json))
            }

            userDefaults.set(Date(), forKey: timestampKey)
            userDefaults.synchronize()
            print("Profile saved to SQLite storage")
        } catch {
            print("Error saving profile: \(error)")
        }
    }

    func loadProfile() -> UserModel? {
        // Expiration check
        if let ts = userDefaults.object(forKey: timestampKey) as? Date {
            let hours = Date().timeIntervalSince(ts) / 3600
            if hours > storageExpirationHours { clearStorage(); return nil }
        } else {
            return nil
        }

        guard let db = db else { return nil }
        do {
            if let row = try db.pluck(table) {
                let json = row[payload]
                guard let data = json.data(using: .utf8) else { return nil }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(UserModel.self, from: data)
            }
        } catch {
            print("Error loading profile: \(error)")
        }
        return nil
    }

    func clearStorage() {
        guard let db = db else { return }
        do {
            try db.run(table.delete())
            userDefaults.removeObject(forKey: timestampKey)
            userDefaults.synchronize()
            print("Profile SQLite storage cleared")
        } catch {
            print("Error clearing profile storage: \(error)")
        }
    }
}
