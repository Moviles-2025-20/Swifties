//
//  NewsStorageService.swift
//  Swifties
//
//  Created by Juan Esteban Vasquez Parra on 27/11/25.
//

import Foundation
import SQLite
import CryptoKit

final class NewsStorageService {
    static let shared = NewsStorageService()

    private let userDefaults = UserDefaults.standard
    private let timestampKey = "cached_news_timestamp"
    private let storageExpirationHours: Double = 24

    // SQLite
    private var db: Connection?
    private let table = Table("news")
    // Columns
    private let id = Expression<String>("id")
    private let eventId = Expression<String>("event_id")
    private let desc = Expression<String>("description")
    private let photoUrl = Expression<String>("photo_url")
    private let ratingsJSON = Expression<String>("ratings_json")
    private let payload = Expression<String>("payload")
    private let createdAt = Expression<Date>("created_at")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
                print("Error: Documents directory unavailable: News.")
                return
            }
            let dbPath = "\(path)/news.sqlite3"
            db = try Connection(dbPath)
            try createTableIfNeeded()
            try createIndexesIfNeeded()
        } catch {
            print("News DB setup error: \(error)")
        }
    }

    private func createTableIfNeeded() throws {
        guard let db = db else { return }
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(eventId)
            t.column(desc)
            t.column(photoUrl)
            t.column(ratingsJSON)
            t.column(payload)
            t.column(createdAt, defaultValue: Date())
        })
    }

    private func createIndexesIfNeeded() throws {
        guard let db = db else { return }
        // Helpful indexes (no-op if already exist)
        try db.run("CREATE INDEX IF NOT EXISTS idx_news_event_id ON news(event_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_news_created_at ON news(created_at)")
    }

    // MARK: - Public API

    func saveNews(_ news: [News]) {
        guard let db = db else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            try db.transaction {
                // Clear table before inserting to replace all cached news
                try db.run(table.delete())

                for item in news {
                    let key = stableKey(for: item)
                    let ratingsStr = try String(data: JSONSerialization.data(withJSONObject: item.ratings, options: []), encoding: .utf8) ?? "[]"
                    let itemJSON = String(data: try encoder.encode(item), encoding: .utf8) ?? "{}"

                    // Insertion after clearing the table
                    let insert = table.insert(id <- key,
                                              eventId <- item.eventId,
                                              desc <- item.description,
                                              photoUrl <- item.photoUrl,
                                              ratingsJSON <- ratingsStr,
                                              payload <- itemJSON,
                                              createdAt <- Date())
                    try db.run(insert)
                }
            }

            userDefaults.set(Date(), forKey: timestampKey)
            print("News saved to SQLite storage (\(news.count) rows)")
        } catch {
            print("Error saving news: \(error)")
        }
    }

    func getStoredNews() -> [News]? {
        // Expiration check
        if let ts = userDefaults.object(forKey: timestampKey) as? Date {
            let hours = Date().timeIntervalSince(ts) / 3600
            if hours > storageExpirationHours {
                clearStorage()
                return nil
            }
        } else {
            return nil
        }

        guard let db = db else { return nil }
        do {
            var result: [News] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Order by createdAt descending or keep insertion order; choose what fits best
            for row in try db.prepare(table.order(createdAt.desc)) {
                let json = row[payload]
                guard let data = json.data(using: .utf8) else { continue }
                do {
                    let item = try decoder.decode(News.self, from: data)
                    result.append(item)
                } catch {
                    // Fallback: reconstruct from columns if payload decoding fails
                    let reconstructed = News(
                        id: row[id],
                        eventId: row[eventId],
                        description: row[desc],
                        photoUrl: row[photoUrl],
                        ratings: (try? decodeRatingsJSON(row[ratingsJSON])) ?? []
                    )
                    result.append(reconstructed)
                }
            }
            return result.isEmpty ? nil : result
        } catch {
            print("Error loading news: \(error)")
            return nil
        }
    }

    func clearStorage() {
        guard let db = db else { return }
        do {
            try db.run(table.delete())
            userDefaults.removeObject(forKey: timestampKey)
            print("News SQLite storage cleared")
        } catch {
            print("Error clearing news storage: \(error)")
        }
    }

    // MARK: - Helpers

    // Prefer the model's id; if nil, synthesize a stable key from content
    private func stableKey(for news: News) -> String {
        if let id = news.id, !id.isEmpty { return id }
        // Deterministic hash from salient fields
        let base = "\(news.eventId)|\(news.description)|\(news.photoUrl)|\(news.ratings.joined(separator: ","))"
        if let data = base.data(using: .utf8) {
            let digest = SHA256.hash(data: data)
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }
        // Fallback (very unlikely)
        return UUID().uuidString
    }

    private func parseJSONArray(_ text: String) -> [String]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String]
    }

    private func decodeRatingsJSON(_ text: String) throws -> [String] {
        guard let arr = parseJSONArray(text) else { return [] }
        return arr
    }
}
