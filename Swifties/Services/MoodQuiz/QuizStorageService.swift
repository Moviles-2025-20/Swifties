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
                        print("!!!!!! Skipping question without ID")
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
                    print("!!!!!! Failed to decode options for question \(row[id])")
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
                        // Handle migrations if needed (LATER FUTURE)
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
    
    // MARK: - Realm Operations (Results) - FIXED!
    
    func saveQuizResult(userId: String, result: QuizResult, userQuizResult: UserQuizResult) {
        // FIX: Use main thread for Realm writes when already on main actor
        do {
            let realm = try Realm()
            
            let realmResult = RealmQuizResult(
                userId: userId,
                result: result,
                userQuizResult: userQuizResult
            )
            
            try realm.write {
                realm.add(realmResult, update: .modified)
            }
            print("✅ [REALM WRITE] Saved quiz result: \(userId) - \(result.moodCategory)")
            print("   Raw category: \(result.rawCategory)")
            print("   Tied categories: \(result.tiedCategories)")
            print("   Total score: \(result.totalScore)")
        } catch {
            print("❌ Error saving to Realm: \(error)")
        }
    }
    
    func loadQuizResult(userId: String) async -> (result: QuizResult, userQuizResult: UserQuizResult)? {
        // FIX: Simplified Realm read on main thread
        do {
            let realm = try await Realm()
            
            guard let realmResult = realm.object(ofType: RealmQuizResult.self, forPrimaryKey: userId) else {
                print("❌ No quiz result found in Realm for: \(userId)")
                return nil
            }
            
            // CRITICAL: Validate the stored data BEFORE converting
            print("✅ [REALM READ] Found result for user: \(userId)")
            print("   Category: \(realmResult.moodCategory)")
            print("   Raw category: \(realmResult.rawCategory)")
            print("   Is tied: \(realmResult.isTied)")
            print("   Total score: \(realmResult.totalScore)")
            print("   UserQuizResult JSON length: \(realmResult.userQuizResultJson.count)")
            
            let result = realmResult.toQuizResult()
            let userQuizResult = realmResult.toUserQuizResult()
            
            // Validate UserQuizResult reconstruction
            print("   Reconstructed scores: \(userQuizResult.scores)")
            print("   Reconstructed categories: \(userQuizResult.resultCategory)")
            
            return (result, userQuizResult)
        } catch {
            print("❌ Error loading from Realm: \(error)")
            return nil
        }
    }
    
    func deleteQuizResult(userId: String) {
        do {
            let realm = try Realm()
            
            if let object = realm.object(ofType: RealmQuizResult.self, forPrimaryKey: userId) {
                try realm.write {
                    realm.delete(object)
                }
                print("✅ Deleted quiz result from Realm: \(userId)")
            }
        } catch {
            print("❌ Error deleting from Realm: \(error)")
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
            print("✅ [USERDEFAULTS] Saved pending result")
            print("   User: \(result.userId)")
            print("   Scores: \(result.scores)")
            print("   Categories: \(result.resultCategory)")
            print("   Selected Questions: \(result.selectedQuestionIds)")
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
        print("✅ Cleared pending UserQuizResult uploads from UserDefaults")
    }
    
    func hasPendingResults() -> Bool {
        return !loadPendingResults().isEmpty
    }
    
    func removePendingResult(userId: String) {
        var pending = loadPendingResults()
        let originalCount = pending.count
        pending.removeAll { $0.userId == userId }
        
        if pending.count < originalCount {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            if let data = try? encoder.encode(pending) {
                UserDefaults.standard.set(data, forKey: pendingResultsKey)
                print("✅ Removed pending result for user: \(userId)")
            } else if pending.isEmpty {
                clearPendingResults()
            }
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
        print("✅ Set wants retake: \(value) for user: \(userId)")
    }
    
    func wantsRetake(userId: String) -> Bool {
        return UserDefaults.standard.bool(forKey: wantsRetakeKey + userId)
    }
    
    func clearQuizState(userId: String) {
        UserDefaults.standard.removeObject(forKey: hasResultKey + userId)
        UserDefaults.standard.removeObject(forKey: wantsRetakeKey + userId)
        print("✅ Cleared quiz state for user: \(userId)")
    }
}

// MARK: - Realm Model for Quiz Result

class RealmQuizResult: Object {
    @Persisted(primaryKey: true) var userId: String
    
    // UI display fields
    @Persisted var moodCategory: String
    @Persisted var rawCategory: String
    @Persisted var isTied: Bool
    @Persisted var tiedCategoriesJson: String
    @Persisted var emoji: String
    @Persisted var resultDescription: String
    @Persisted var totalScore: Int
    
    // Full UserQuizResult encoded for reconstruction
    @Persisted var userQuizResultJson: String
    
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
        } else {
            self.tiedCategoriesJson = "[]"
        }
        
        // Encode UserQuizResult
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(userQuizResult),
           let json = String(data: data, encoding: .utf8) {
            self.userQuizResultJson = json
            print("✅ [REALM INIT] Encoded UserQuizResult successfully")
        } else {
            print("❌ [REALM INIT] Failed to encode UserQuizResult!")
            self.userQuizResultJson = ""
        }
    }
    
    func toQuizResult() -> QuizResult {
        let tiedCategories: [String]
        if let data = tiedCategoriesJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            tiedCategories = decoded
        } else {
            tiedCategories = []
        }
        
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
    
    func toUserQuizResult() -> UserQuizResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard !userQuizResultJson.isEmpty,
              let data = userQuizResultJson.data(using: .utf8),
              let result = try? decoder.decode(UserQuizResult.self, from: data) else {
            print("❌ [REALM] Failed to decode UserQuizResult from stored JSON")
            print("   JSON length: \(userQuizResultJson.count)")
            print("   JSON preview: \(String(userQuizResultJson.prefix(100)))")
            
            // Fatal error with diagnostic info
            fatalError("Failed to decode UserQuizResult from Realm for user: \(userId)")
        }
        
        return result
    }
}
