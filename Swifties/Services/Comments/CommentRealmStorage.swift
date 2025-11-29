import Combine
import Foundation
import RealmSwift

class CommentRealmStorage {
    static let shared = CommentRealmStorage()
    
    private let configuration: Realm.Configuration
    private let realmQueue = DispatchQueue(label: "CommentRealmStorage.realmQueue")
    
    private init() {
        // Align schemaVersion with other services (WeeklyChallenge/WishMeLuck use 1)
        configuration = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // Add migration steps if you ever bump schemaVersion > 1
                if oldSchemaVersion < 1 {
                    // No-op: v1 initial schema for comments
                }
            }
        )
        // Optionally set as default to keep entire app consistent
        // Realm.Configuration.defaultConfiguration = configuration
        print("✅ Using Realm configuration (schemaVersion: \(configuration.schemaVersion)) for CommentRealmStorage")
    }
    
    func save(comment: StoredComment, id: String) {
        let encoder = JSONEncoder()
        var data: Data
        do {
            data = try encoder.encode(comment)
        } catch {
            print("Cannot use encoder for comment with id \(id). Saving operation skipped with error: \(error)")
            return
        }
        let object = RealmPendingComment()
        object.id = id
        object.json = data
        object.createdAt = Date()
        realmQueue.async {
            do {
                let realm = try Realm(configuration: self.configuration)
                try realm.write {
                    realm.add(object, update: .modified)
                }
            } catch {
                print("Failed to save comment with id \(id): \(error)")
            }
        }
    }
    
    // Async version that performs Realm I/O on realmQueue and resumes with the result
    func load(id: String) async -> StoredComment? {
        await withCheckedContinuation { continuation in
            realmQueue.async {
                do {
                    let realm = try Realm(configuration: self.configuration)
                    guard let object = realm.object(ofType: RealmPendingComment.self, forPrimaryKey: id) else {
                        print("Failed to load comment with id \(id): Not found in database")
                        continuation.resume(returning: nil)
                        return
                    }
                    let decoder = JSONDecoder()
                    let comment = try decoder.decode(StoredComment.self, from: object.json)
                    continuation.resume(returning: comment)
                } catch {
                    print("Failed to load comment with id \(id): \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Async version that performs Realm I/O on realmQueue and resumes with the array
    func loadAll() async -> [StoredComment] {
        await withCheckedContinuation { continuation in
            realmQueue.async {
                do {
                    let realm = try Realm(configuration: self.configuration)
                    let objects = realm.objects(RealmPendingComment.self).sorted(byKeyPath: "createdAt", ascending: true)
                    let decoder = JSONDecoder()
                    var comments: [StoredComment] = []
                    for object in objects {
                        do {
                            let comment = try decoder.decode(StoredComment.self, from: object.json)
                            comments.append(comment)
                        } catch {
                            print("Failed to decode comment with id \(object.id): \(error)")
                        }
                    }
                    continuation.resume(returning: comments)
                } catch {
                    print("Failed to open Realm for loadAll(): \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func remove(id: String) {
        realmQueue.async {
            do {
                let realm = try Realm(configuration: self.configuration)
                guard let object = realm.object(ofType: RealmPendingComment.self, forPrimaryKey: id) else {
                    return
                }
                try realm.write {
                    realm.delete(object)
                }
            } catch {
                print("Failed to remove comment with id \(id): \(error)")
            }
        }
    }
    
    func removeAll() {
        realmQueue.async {
            do {
                let realm = try Realm(configuration: self.configuration)
                let objects = realm.objects(RealmPendingComment.self)
                try realm.write {
                    realm.delete(objects)
                }
            } catch {
                print("Failed to remove all comments: \(error)")
            }
        }
    }
}

class RealmPendingComment: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var json: Data = Data()
    @Persisted var createdAt: Date = Date()
}

public struct StoredMetadata: Codable, Sendable {
    let image: Data?
    let title: String
    let text: String
        
    enum CodingKeys: String, CodingKey {
        case image
        case title
        case text
    }
}

public struct StoredComment: Codable, Sendable {
    let id: String?
    let created: Date
    let eventId: String
    let userId: String
    let metadata: StoredMetadata
    let rating: Int?
    let emotion: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case created
        case eventId = "event_id"
        case userId = "user_id"
        case metadata
        case rating
        case emotion
    }
}
