//
//  QuizStorageService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/11/25.
//

import Foundation
import SQLite
import RealmSwift

class QuizStorageService {
    static let shared = QuizStorageService()
    
    // SQLite for questions
    private var db: Connection?
    private let questionsTable = Table("quiz_questions")
    private let id = Expression<String>("id")
    private let text = Expression<String>("text")
    private let imageUrl = Expression<String?>("image_url")
    private let optionsJson = Expression<String>("options_json")
    private let timestamp = Expression<Date>("timestamp")
    
    // Realm queue for thread-safe operations
    private let realmQueue = DispatchQueue(label: "com.swifties.quizRealmQueue", qos: .userInitiated)
    
    // UserDefaults keys
    private let pendingResultsKey = "pending_quiz_results"
    private let hasResultKey = "quiz_has_result_"
    private let wantsRetakeKey = "quiz_wants_retake_"
    
    private init() {
        setupSQLite()
        setupRealm()
    }
    
    // MARK: - SQLite Setup
    
    private func setupSQLite() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            
            let dbPath = "\(path)/quiz_questions.sqlite3"
            db = try Connection(dbPath)
            
            print("Quiz questions database path: \(dbPath)")
            createQuestionsTable()
            createIndexes()
        } catch {
            print("❌ Error setting up quiz questions database: \(error)")
        }
    }
    
    private func createQuestionsTable() {
        guard let db = db else { return }
        
        do {
            try db.run(questionsTable.create(ifNotExists: true) { table in
                table.column(id, primaryKey: true)
                table.column(text)
                table.column(imageUrl)
                table.column(optionsJson)
                table.column(timestamp)
            })
            
            print("✅ Quiz questions table created")
        } catch {
            print("❌ Error creating questions table: \(error)")
        }
    }
    
    private func createIndexes() {
        guard let db = db else { return }
        
        do {
            try db.run("CREATE INDEX IF NOT EXISTS idx_quiz_timestamp ON quiz_questions(timestamp)")
            print("✅ Quiz questions indexes created")
        } catch {
            print("❌ Error creating indexes: \(error)")
        }
    }
    
    // MARK: - SQLite Operations (Questions)
    
    func saveQuestions(_ questions: [QuizQuestion]) {
        guard let db = db else {
            print("❌ Database connection not available")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            
            try db.transaction {
                // Clear existing questions
                try db.run(questionsTable.delete())
                
                for question in questions {
                    guard let questionId = question.id else {
                        print("⚠️ Skipping question without ID")
                        continue
                    }
                    
                    let optionsData = try encoder.encode(question.options)
                    let optionsString = String(data: optionsData, encoding: .utf8)!
                    
                    let insert = questionsTable.insert(
                        id <- questionId,
                        text <- question.text,
                        imageUrl <- question.imageUrl,
                        optionsJson <- optionsString,
                        timestamp <- Date()
                    )
                    
                    try db.run(insert)
                }
            }
            
            print("✅ \(questions.count) quiz questions saved to SQLite")
        } catch {
            print("❌ Error saving quiz questions: \(error)")
        }
    }
    
    func loadQuestions() -> [QuizQuestion]? {
        guard let db = db else {
            print("❌ Database connection not available")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            var questions: [QuizQuestion] = []
            
            for row in try db.prepare(questionsTable) {
                guard let optionsData = row[optionsJson].data(using: .utf8) else {
                    print("⚠️ Failed to decode options for question \(row[id])")
                    continue
                }
                
                let options = try decoder.decode([QuizOption].self, from: optionsData)
                
                var question = QuizQuestion(
                    text: row[text],
                    imageUrl: row[imageUrl],
                    options: options
                )
                question.id = row[id]
                
                questions.append(question)
            }
            
            print("✅ \(questions.count) quiz questions loaded from SQLite")
            return questions.isEmpty ? nil : questions
        } catch {
            print("❌ Error loading quiz questions: \(error)")
            return nil
        }
    }
    
    func deleteQuestions() {
        guard let db = db else { return }
        
        do {
            let deleted = try db.run(questionsTable.delete())
            print("✅ \(deleted) quiz questions deleted from SQLite")
        } catch {
            print("❌ Error deleting quiz questions: \(error)")
        }
    }
    
    // MARK: - Realm Setup
    
    private func setupRealm() {
        do {
            let config = Realm.Configuration(
                schemaVersion: 2,
                migrationBlock: { migration, oldSchemaVersion in
                    if oldSchemaVersion < 2 {
                        // Handle migrations if needed -FUTURE IMPLEMENTATION
                    }
                }
            )
            
            Realm.Configuration.defaultConfiguration = config
            _ = try Realm()
            print("✅ Realm initialized for Quiz")
        } catch {
            print("❌ Error initializing Realm: \(error)")
        }
    }
    
    // MARK: - Realm Operations (Results)
    
    func saveQuizResult(userId: String, result: QuizResult, userQuizResult: UserQuizResult) {
        realmQueue.async { [weak self] in
            guard let _ = self else { return }
            
            guard let realm = try? Realm() else {
                print("❌ Realm not initialized")
                return
            }
            
            let realmResult = RealmQuizResult(
                userId: userId,
                result: result,
                userQuizResult: userQuizResult
            )
            
            do {
                try realm.write {
                    realm.add(realmResult, update: .modified)
                }
                print("[SAVEDDD] Saved quiz result to Realm: \(userId) - \(result.moodCategory)")
            } catch {
                print("❌ Error saving to Realm: \(error)")
            }
        }
    }
    
    func loadQuizResult(userId: String) async -> (result: QuizResult, userQuizResult: UserQuizResult)? {
        return await withCheckedContinuation { continuation in
            realmQueue.async { [weak self] in
                guard let _ = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let realm = try? Realm() else {
                    print("❌ Realm not initialized")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let realmResult = realm.object(ofType: RealmQuizResult.self, forPrimaryKey: userId) else {
                    print("❌ No quiz result found in Realm for: \(userId)")
                    continuation.resume(returning: nil)
                    return
                }
                
                let result = realmResult.toQuizResult()
                let userQuizResult = realmResult.toUserQuizResult()
                
                print("✅ Loaded quiz result from Realm: \(userId)")
                continuation.resume(returning: (result, userQuizResult))
            }
        }
    }
    
    func deleteQuizResult(userId: String) {
        realmQueue.async { [weak self] in
            guard let _ = self else { return }
            guard let realm = try? Realm() else { return }
            
            if let object = realm.object(ofType: RealmQuizResult.self, forPrimaryKey: userId) {
                do {
                    try realm.write {
                        realm.delete(object)
                    }
                    print("XXXXX Deleted quiz result from Realm: \(userId)")
                } catch {
                    print("❌ Error deleting from Realm: \(error)")
                }
            }
        }
    }
    
    // MARK: - UserDefaults Operations (Pending Uploads & State)
    
    func savePendingResult(_ result: UserQuizResult) {
        var pending = loadPendingResults()
        
        // Remove any existing pending result for this user (avoid duplicates)
        pending.removeAll { $0.userId == result.userId }
        
        // Add the new result
        pending.append(result)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingResultsKey)
            print("[SAVEDDDD] Saved pending UserQuizResult to UserDefaults for upload")
            print("   User: \(result.userId)")
            print("   Categories: \(result.resultCategory)")
            print("   Type: \(result.resultType)")
        }
    }
    
    func loadPendingResults() -> [UserQuizResult] {
        guard let data = UserDefaults.standard.data(forKey: pendingResultsKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let results = (try? decoder.decode([UserQuizResult].self, from: data)) ?? []
        if !results.isEmpty {
            print("✅ Loaded \(results.count) pending UserQuizResult(s) from UserDefaults")
        }
        return results
    }
    
    func clearPendingResults() {
        UserDefaults.standard.removeObject(forKey: pendingResultsKey)
        print("XXXXXXXX Cleared pending UserQuizResult uploads from UserDefaults")
    }
    
    func hasPendingResults() -> Bool {
        return !loadPendingResults().isEmpty
    }
    
    func removePendingResult(userId: String) {
        var pending = loadPendingResults()
        pending.removeAll { $0.userId == userId }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(pending) {
            UserDefaults.standard.set(data, forKey: pendingResultsKey)
            print("XXXXXXXX Removed pending result for user: \(userId)")
        } else if pending.isEmpty {
            // If no pending results left, clear the key
            clearPendingResults()
        }
    }
    
    // MARK: - Quiz State Flags
    
    func setHasResult(userId: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: hasResultKey + userId)
    }
    
    func hasResult(userId: String) -> Bool {
        return UserDefaults.standard.bool(forKey: hasResultKey + userId)
    }
    
    func setWantsRetake(userId: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: wantsRetakeKey + userId)
        print(" Set wants retake: \(value) for user: \(userId)")
    }
    
    func wantsRetake(userId: String) -> Bool {
        return UserDefaults.standard.bool(forKey: wantsRetakeKey + userId)
    }
    
    func clearQuizState(userId: String) {
        UserDefaults.standard.removeObject(forKey: hasResultKey + userId)
        UserDefaults.standard.removeObject(forKey: wantsRetakeKey + userId)
        print("XXXXXXXX Cleared quiz state for user: \(userId)")
    }
}

// MARK: - Realm Model for Quiz Result

/// Stores UI-friendly quiz result data for displaying the result screen
///
/// **Purpose**: Allow user to see their quiz result (emoji, description, etc.)
/// even when offline or when UserQuizResult upload is pending.
///
/// **Separation of Concerns**:
/// - This model = "What does the user SEE?" (emoji, description, display name)
/// - UserQuizResult in UserDefaults pending = "What does Firebase NEED?" (scores, question IDs, etc.)
///
/// Both are created from the same quiz completion, but serve different purposes.
class RealmQuizResult: Object {
    @Persisted(primaryKey: true) var userId: String
    
    // UI display fields
    @Persisted var moodCategory: String        // Display name: "Creative"
    @Persisted var rawCategory: String         // Key: "creative"
    @Persisted var isTied: Bool               // Multiple categories tied?
    @Persisted var tiedCategoriesJson: String // JSON array of tied keys
    @Persisted var emoji: String              // "🎨"
    @Persisted var resultDescription: String  // User-facing description
    @Persisted var totalScore: Int
    
    // Full UserQuizResult encoded for reconstruction
    @Persisted var userQuizResultJson: String // Complete Firebase upload data
    
    @Persisted var lastUpdated: Date = Date()
    
    convenience init(userId: String, result: QuizResult, userQuizResult: UserQuizResult) {
        self.init()
        self.userId = userId
        self.moodCategory = result.moodCategory
        self.rawCategory = result.rawCategory
        self.isTied = result.isTied
        self.emoji = result.emoji
        self.resultDescription = result.description
        self.totalScore = result.totalScore
        self.lastUpdated = Date()
        
        // Encode tied categories
        if let data = try? JSONEncoder().encode(result.tiedCategories),
           let json = String(data: data, encoding: .utf8) {
            self.tiedCategoriesJson = json
        }
        
        // Encode UserQuizResult for later reconstruction (if needed)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(userQuizResult),
           let json = String(data: data, encoding: .utf8) {
            self.userQuizResultJson = json
        }
    }
    
    /// Converts to QuizResult for UI display
    func toQuizResult() -> QuizResult {
        let tiedCategories = (try? JSONDecoder().decode([String].self, from: tiedCategoriesJson.data(using: .utf8)!)) ?? []
        
        return QuizResult(
            moodCategory: moodCategory,
            rawCategory: rawCategory,
            isTied: isTied,
            tiedCategories: tiedCategories,
            emoji: emoji,
            description: resultDescription,
            totalScore: totalScore
        )
    }
    
    /// Reconstructs UserQuizResult from stored JSON (if needed for re-upload)
    func toUserQuizResult() -> UserQuizResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let data = userQuizResultJson.data(using: .utf8),
              let result = try? decoder.decode(UserQuizResult.self, from: data) else {
            fatalError("Failed to decode UserQuizResult from Realm")
        }
        
        return result
    }
}
