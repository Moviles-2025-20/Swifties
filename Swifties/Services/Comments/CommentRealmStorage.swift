import Combine
import Foundation
import RealmSwift

class CommentRealmStorage {
    static let shared = CommentRealmStorage()
    
    private let configuration: Realm.Configuration
    private let realmQueue = DispatchQueue(label: "CommentRealmStorage.realmQueue")
    
    private init() {
        configuration = Realm.Configuration.defaultConfiguration
        print("✅ Using default Realm configuration")
    }
    
    func save(comment: StoredComment, id: String) {
        let encoder = JSONEncoder()
        var data: Data
        do {
            data = try encoder.encode(comment)
        } catch {
            print("Cannot use encoder for comment with id \(id): \(error)")
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
    
    func load(id: String) -> StoredComment? {
        guard let realm = try? Realm(configuration: configuration) else {
            print("Failed to open Realm for load(id:): unable to create Realm instance")
            return nil
        }
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
        guard let realm = try? Realm(configuration: configuration) else {
            print("Failed to open Realm for loadAll()")
            return []
        }
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
        guard (try? Realm(configuration: configuration)) != nil else {
            print("Failed to open Realm for remove(id:)")
            return
        }
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
