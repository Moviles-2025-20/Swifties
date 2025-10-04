import Foundation
struct WishMeLuckEvent: Codable, Identifiable {
    let id: String
    let title: String
    let imageUrl: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageUrlSnake = "image_url"
        case imageUrlCamel = "imageUrl"
        case description
        case metadata
    }
    
    enum MetadataKeys: String, CodingKey {
        case imageUrlSnake = "image_url"
        case imageUrlCamel = "imageUrl"
    }
    
    init(id: String, title: String, imageUrl: String, description: String) {
        self.id = id
        self.title = title
        self.imageUrl = imageUrl
        self.description = description
    }
    
    // MARK: - Decodable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Event"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? "No description available"
        
        if let snake = try? container.decode(String.self, forKey: .imageUrlSnake) {
            imageUrl = snake
        } else if let camel = try? container.decode(String.self, forKey: .imageUrlCamel) {
            imageUrl = camel
        } else if let metadata = try? container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata) {
            if let metaSnake = try? metadata.decode(String.self, forKey: .imageUrlSnake) {
                imageUrl = metaSnake
            } else if let metaCamel = try? metadata.decode(String.self, forKey: .imageUrlCamel) {
                imageUrl = metaCamel
            } else {
                imageUrl = ""
            }
        } else {
            imageUrl = ""
        }
    }
    
    // MARK: - Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(imageUrl, forKey: .imageUrlCamel) // uses camelCase when saving
    }
    
    // MARK: - Helper
    static func fromEvent(_ event: Event) -> WishMeLuckEvent {
        // Use event.id if it exists, otherwise fallback to event.title or a generated UUID
        let eventId: String
        if let id = (event as? (AnyObject & NSObjectProtocol))?.value(forKey: "id") as? String {
            eventId = id
        } else if let title = event.title as? String {
            eventId = title
        } else {
            eventId = UUID().uuidString
        }
        return WishMeLuckEvent(
            id: eventId,
            title: event.title,
            imageUrl: event.metadata.imageUrl ?? "",
            description: event.description
        )
    }
}
