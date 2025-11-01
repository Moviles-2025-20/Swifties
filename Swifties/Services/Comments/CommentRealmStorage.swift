import Combine
import Foundation
import RealmSwift

class CommentRealmStorage {
    static let shared = CommentRealmStorage()
    
    private let realm: Realm
    
    private init() {
        do {
            realm = try Realm()
        } catch {
            print("⚠️ Failed to initialize Realm: \(error)")
            do {
                realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "InMemoryRealm"))
                print("✅ Using in-memory Realm fallback")
            } catch {
                fatalError("❌ Failed to initialize even in-memory Realm: \(error)")
            }
        }
    }

    
    func save(comment: StoredComment, id: String) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(comment)
            let object = RealmPendingComment()
            object.id = id
            object.json = data
            object.createdAt = Date()
            try realm.write {
                realm.add(object, update: .modified)
            }
        } catch {
            print("Failed to save comment with id \(id): \(error)")
        }
    }
    
    func load(id: String) -> StoredComment? {
        guard let object = realm.object(ofType: RealmPendingComment.self, forPrimaryKey: id) else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            let comment = try decoder.decode(StoredComment.self, from: object.json)
            return comment
        } catch {
            print("Failed to decode comment with id \(id): \(error)")
            return nil
        }
    }
    
    func loadAll() -> [StoredComment] {
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
        return comments
    }
    
    func remove(id: String) {
        guard let object = realm.object(ofType: RealmPendingComment.self, forPrimaryKey: id) else {
            return
        }
        do {
            try realm.write {
                realm.delete(object)
            }
        } catch {
            print("Failed to remove comment with id \(id): \(error)")
        }
    }
    
    func removeAll() {
        let objects = realm.objects(RealmPendingComment.self)
        do {
            try realm.write {
                realm.delete(objects)
            }
        } catch {
            print("Failed to remove all comments: \(error)")
        }
    }
}

class RealmPendingComment: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var json: Data = Data()
    @Persisted var createdAt: Date = Date()
}

public struct StoredMetadata: Codable {
    let image: Data?
    let title: String
    let text: String
        
    enum CodingKeys: String, CodingKey {
        case image
        case title
        case text
    }
}

public struct StoredComment: Codable {
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
