//
//  QuizNetworkService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/11/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class QuizNetworkService {
    static let shared = QuizNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    
    // The actual Firestore structure
    private let quizDocumentId = "lOhEPYC8ci9lBEo08G47"  // The document ID of the loaded questions
    
    private init() {}
    
    // MARK: - Fetch Quiz Questions
    
    func fetchQuizQuestions(completion: @escaping (Result<[QuizQuestion], Error>) -> Void) {
        print("[FETCHING] Fetching quiz questions from Firestore...")
        
        // Fetch from the single document that contains the questions array
        db.collection("quiz_questions")
            .document(quizDocumentId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("❌ Network error fetching questions: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot, document.exists else {
                    let error = NSError(
                        domain: "QuizNetwork",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Quiz questions document not found"]
                    )
                    print("❌ Document quiz_questions/\(self.quizDocumentId) not found")
                    completion(.failure(error))
                    return
                }
                
                guard let data = document.data(),
                      let questionsArray = data["questions"] as? [[String: Any]] else {
                    let error = NSError(
                        domain: "QuizNetwork",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "No questions array found in document"]
                    )
                    print("❌ No 'questions' field found in document")
                    completion(.failure(error))
                    return
                }
                
                print("[FOUND] Found \(questionsArray.count) questions in array, parsing...")
                
                var questions: [QuizQuestion] = []
                var parseErrors: [String] = []
                
                for (index, questionData) in questionsArray.enumerated() {
                    // Parse question
                    guard let id = questionData["id"] as? String,
                          let text = questionData["text"] as? String else {
                        parseErrors.append("Question \(index): Missing 'id' or 'text' field")
                        continue
                    }
                    
                    // imageUrl is optional
                    let imageUrl = questionData["imageUrl"] as? String
                    
                    // Parse options array
                    guard let optionsArray = questionData["options"] as? [[String: Any]] else {
                        parseErrors.append("Question '\(id)': Missing or invalid 'options' array")
                        continue
                    }
                    
                    var options: [QuizOption] = []
                    var hasValidOptions = true
                    
                    for (optIndex, optionData) in optionsArray.enumerated() {
                        guard let optionText = optionData["text"] as? String,
                              let category = optionData["category"] as? String,
                              let points = optionData["points"] as? Int else {
                            parseErrors.append("Question '\(id)' option \(optIndex): Missing text/category/points")
                            hasValidOptions = false
                            break
                        }
                        
                        // Validate category
                        let validCategories = ["creative", "social_planner", "cultural_explorer", "chill"]
                        guard validCategories.contains(category) else {
                            parseErrors.append("Question '\(id)': Invalid category '\(category)'")
                            hasValidOptions = false
                            break
                        }
                        
                        // Validate points
                        guard points >= 0 && points <= 100 else {
                            parseErrors.append("Question '\(id)': Invalid points value \(points)")
                            hasValidOptions = false
                            break
                        }
                        
                        options.append(QuizOption(text: optionText, category: category, points: points))
                    }
                    
                    if !hasValidOptions || options.isEmpty {
                        parseErrors.append("Question '\(id)': No valid options")
                        continue
                    }
                    
                    // Create question with ID
                    var question = QuizQuestion(text: text, imageUrl: imageUrl, options: options)
                    question.id = id
                    
                    questions.append(question)
                    print("✅ Parsed question \(index + 1): \(id)")
                }
                
                // Report parsing results
                if !parseErrors.isEmpty {
                    print("\n⚠️ PARSING ERRORS (\(parseErrors.count) issues):")
                    parseErrors.prefix(5).forEach { print("   - \($0)") }
                    if parseErrors.count > 5 {
                        print("   ... and \(parseErrors.count - 5) more")
                    }
                }
                
                if questions.isEmpty {
                    let error = NSError(
                        domain: "QuizNetwork",
                        code: 400,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to parse any quiz questions",
                            NSLocalizedFailureReasonErrorKey: parseErrors.joined(separator: "\n")
                        ]
                    )
                    print("❌ Failed to parse any questions from \(questionsArray.count) items")
                    completion(.failure(error))
                    return
                }
                
                print("✅ Successfully parsed \(questions.count) out of \(questionsArray.count) questions")
                completion(.success(questions))
            }
    }
    
    // MARK: - Upload Quiz Result
    
    func uploadQuizResult(_ result: UserQuizResult, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[UPLOADING] Uploading quiz result to Firestore...")
        print("   User: \(result.userId)")
        print("   Quiz Bank: \(result.quizBankId)")
        print("   Result Type: \(result.resultType)")
        
        let resultRef = db.collection("user_quiz_results").document()
        
        // Use toFirestoreData() to properly convert Date to Timestamp
        let firestoreData = result.toFirestoreData()
        
        resultRef.setData(firestoreData) { error in
            if let error = error {
                print("❌ Error uploading quiz result: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Quiz result uploaded successfully to document: \(resultRef.documentID)")
            completion(.success(()))
        }
    }
    
    // MARK: - Sync Pending Results
    
    func syncPendingResults(results: [UserQuizResult], completion: @escaping (Result<Void, Error>) -> Void) {
        print("[SYNC] Syncing \(results.count) pending quiz result(s)...")
        
        guard !results.isEmpty else {
            completion(.success(()))
            return
        }
        
        let batch = db.batch()
        
        for result in results {
            let ref = db.collection("user_quiz_results").document()
            let firestoreData = result.toFirestoreData()
            batch.setData(firestoreData, forDocument: ref)
            
            print("   [+] Prepared: User \(result.userId) - \(result.resultType) result")
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Batch sync failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Successfully synced \(results.count) quiz result(s) to Firestore")
            completion(.success(()))
        }
    }
}
