//
//  QuizNetworkService.swift
//  Swifties
//
//  Network layer for Mood Quiz - fetches questions and uploads results
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class QuizNetworkService {
    static let shared = QuizNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    private let quizBankId = "quiz_bank_v1" // Your quiz bank ID
    
    private init() {}
    
    // MARK: - Fetch Quiz Questions
    
    func fetchQuizQuestions(completion: @escaping (Result<[QuizQuestion], Error>) -> Void) {
        print("🌐 Fetching quiz questions from Firestore...")
        
        db.collection("quiz_banks")
            .document(quizBankId)
            .collection("questions")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Network error fetching questions: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    let error = NSError(
                        domain: "QuizNetwork",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "No quiz questions found"]
                    )
                    completion(.failure(error))
                    return
                }
                
                let questions = documents.compactMap { doc -> QuizQuestion? in
                    try? doc.data(as: QuizQuestion.self)
                }
                
                if questions.isEmpty {
                    let error = NSError(
                        domain: "QuizNetwork",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse quiz questions"]
                    )
                    completion(.failure(error))
                    return
                }
                
                print("✅ Fetched \(questions.count) quiz questions from network")
                completion(.success(questions))
            }
    }
    
    // MARK: - Upload Quiz Result
    
    func uploadQuizResult(_ result: UserQuizResult, completion: @escaping (Result<Void, Error>) -> Void) {
        print("☁️ Uploading quiz result to Firestore...")
        
        let resultRef = db.collection("user_quiz_results").document()
        
        do {
            try resultRef.setData(from: result) { error in
                if let error = error {
                    print("❌ Error uploading quiz result: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                print("✅ Quiz result uploaded successfully")
                completion(.success(()))
            }
        } catch {
            print("❌ Error encoding quiz result: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // MARK: - Sync Pending Results
    
    func syncPendingResults(results: [UserQuizResult], completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔄 Syncing \(results.count) pending quiz results...")
        
        let batch = db.batch()
        
        for result in results {
            let ref = db.collection("user_quiz_results").document()
            do {
                try batch.setData(from: result, forDocument: ref)
            } catch {
                print("❌ Error preparing batch for result: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Batch sync failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Successfully synced \(results.count) quiz results")
            completion(.success(()))
        }
    }
}