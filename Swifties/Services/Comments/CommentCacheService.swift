import Foundation

struct CachedComment: Codable {
    let localId: String
    let comment: Comment
    let imageData: Data?
}

final class CommentCacheService {
    static let shared = CommentCacheService()
    
    private let cache: LRUCache<String, CachedComment>
    private let queue = DispatchQueue(label: "com.commentCacheService.queue", attributes: .concurrent)
    
    init(capacity: Int = 200) {
        self.cache = LRUCache<String, CachedComment>(capacity: capacity)
    }
    
    func set(_ cached: CachedComment, for id: String) {
        queue.async(flags: .barrier) {
            self.cache.set(value: cached, for: id)
        }
    }
    
    func set(comment: Comment, for id: String, imageData: Data? = nil) {
        let cached = CachedComment(localId: id, comment: comment, imageData: imageData)
        set(cached, for: id)
    }
    
    func get(id: String) -> CachedComment? {
        var result: CachedComment?
        queue.sync {
            result = self.cache.get(for: id)
        }
        return result
    }
    
    func remove(id: String) {
        queue.async(flags: .barrier) {
            self.cache.remove(for: id)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    func all() -> [CachedComment] {
        var result: [CachedComment] = []
        queue.sync {
            result = self.cache.allValues()
        }
        return result
    }
}

private final class LRUCache<Key: Hashable, Value> {
    private class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private let capacity: Int
    private var map: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    
    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }
    
    func get(for key: Key) -> Value? {
        guard let node = map[key] else {
            return nil
        }
        moveToHead(node)
        return node.value
    }
    
    func set(value: Value, for key: Key) {
        if let node = map[key] {
            node.value = value
            moveToHead(node)
        } else {
            let newNode = Node(key: key, value: value)
            map[key] = newNode
            addNodeAtHead(newNode)
            if map.count > capacity {
                removeTail()
            }
        }
    }
    
    func remove(for key: Key) {
        guard let node = map[key] else {
            return
        }
        removeNode(node)
        map[key] = nil
    }
    
    func removeAll() {
        map.removeAll()
        head = nil
        tail = nil
    }
    
    func allValues() -> [Value] {
        var values: [Value] = []
        var current = head
        while let node = current {
            values.append(node.value)
            current = node.next
        }
        return values
    }
    
    // MARK: - Private helpers
    private func addNodeAtHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: Node) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }
        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }
        node.prev = nil
        node.next = nil
    }
    
    private func moveToHead(_ node: Node) {
        removeNode(node)
        addNodeAtHead(node)
    }
    
    private func removeTail() {
        guard let tailNode = tail else {
            return
        }
        removeNode(tailNode)
        map[tailNode.key] = nil
    }
}
