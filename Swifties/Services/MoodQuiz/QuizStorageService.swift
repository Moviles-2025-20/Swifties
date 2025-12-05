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
    
    // Use the singleton DatabaseManager instead of separate connection
    private let dbManager = DatabaseManager.shared
    private let threadManager = ThreadManager.shared
    
    // Table reference (using the centralized table definition)
    private let questionsTable = QuizQuestionsTable.table
    private let id = QuizQuestionsTable.id
    private let text = QuizQuestionsTable.text
    private let imageUrl = QuizQuestionsTable.imageUrl
    private let optionsJson = QuizQuestionsTable.optionsJson
    private let timestamp = QuizQuestionsTable.timestamp
    
    // UserDefaults keys
    private let pendingResultsKey = "pending_quiz_results"
    private let hasResultKey = "quiz_has_result_"
    private let wantsRetakeKey = "quiz_wants_retake_"
    
    private init() {
        setupRealm()
        // Table setup is now handled by DatabaseManager.setupAllTables()
    }
    
    // MARK: - SQLite Operations (Questions)
    
    func saveQuestions(_ questions: [QuizQuestion]) {
        guard !questions.isEmpty else {
            print("⚠️ No questions to save")
            return
        }
        
        // Use DatabaseManager's transaction method with GCD handled internally
        dbManager.executeTransaction { db in
            let encoder = JSONEncoder()
            
            // Clear existing questions
            try db.run(self.questionsTable.delete())
            
            for question in questions {
                guard let questionId = question.id else {
                    print("⚠️ Skipping question without ID")
                    continue
                }
                
                let optionsData = try encoder.encode(question.options)
                let optionsString = String(data: optionsData, encoding: .utf8)!
                
                let insert = self.questionsTable.insert(
                    self.id <- questionId,
                    self.text <- question.text,
                    self.imageUrl <- question.imageUrl,
                    self.optionsJson <- optionsString,
                    self.timestamp <- Date()
                )
                
                try db.run(insert)
            }
            
            print("✅ \(questions.count) quiz questions saved to SQLite")
        } completion: { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("❌ Error saving quiz questions: \(error)")
            }
        }
    }
    
    func loadQuestions(completion: @escaping ([QuizQuestion]?) -> Void) {
        // Use DatabaseManager's read method with GCD handled internally
        dbManager.executeRead { db in
            let decoder = JSONDecoder()
            var questions: [QuizQuestion] = []
            
            for row in try db.prepare(self.questionsTable) {
                guard let optionsData = row[self.optionsJson].data(using: .utf8) else {
                    print("⚠️ Failed to decode options for question \(row[self.id])")
                    continue
                }
                
                let options = try decoder.decode([QuizOption].self, from: optionsData)
                
                var question = QuizQuestion(
                    text: row[self.text],
                    imageUrl: row[self.imageUrl],
                    options: options
                )
                question.id = row[self.id]
                
                questions.append(question)
            }
            
            print("✅ \(questions.count) quiz questions loaded from SQLite")
            return questions.isEmpty ? nil : questions
            
        } completion: { result in
            switch result {
            case .success(let questions):
                completion(questions)
            case .failure(let error):
                print("❌ Error loading quiz questions: \(error)")
                completion(nil)
            }
        }
    }
    
    func deleteQuestions(completion: ((Bool) -> Void)? = nil) {
        dbManager.executeWrite { db in
            let deleted = try db.run(self.questionsTable.delete())
            print("✅ \(deleted) quiz questions deleted from SQLite")
        } completion: { result in
            switch result {
            case .success:
                completion?(true)
            case .failure(let error):
                print("❌ Error deleting quiz questions: \(error)")
                completion?(false)
            }
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
    
    // MARK: - Realm Operations (Results)
    
    func saveQuizResult(userId: String, result: QuizResult, userQuizResult: UserQuizResult) {
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
        do {
            let realm = try await Realm()
            
            guard let realmResult = realm.object(ofType: RealmQuizResult.self, forPrimaryKey: userId) else {
                print("❌ No quiz result found in Realm for: \(userId)")
                return nil
            }
            
            print("✅ [REALM READ] Found result for user: \(userId)")
            print("   Category: \(realmResult.moodCategory)")
            print("   Raw category: \(realmResult.rawCategory)")
            print("   Is tied: \(realmResult.isTied)")
            print("   Total score: \(realmResult.totalScore)")
            print("   UserQuizResult JSON length: \(realmResult.userQuizResultJson.count)")
            
            let result = realmResult.toQuizResult()
            let userQuizResult = realmResult.toUserQuizResult()
            
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
            
            fatalError("Failed to decode UserQuizResult from Realm for user: \(userId)")
        }
        
        return result
    }
}
