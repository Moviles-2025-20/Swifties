//
//  UserQuizResult.swift
//  Swifties
//
//  Created by Assistant on 27/11/25.
//

import Foundation
import FirebaseFirestore

// MARK: - User Quiz Result Model
struct UserQuizResult: Codable {
    let userId: String
    let quizBankId: String
    let timestamp: Date
    let selectedQuestionIds: [String]
    let scores: [String: Int]
    let resultCategory: [String]  // Array to support multiple categories in ties
    let resultType: String  // "single" or "mixed"
    
    enum CodingKeys: String, CodingKey {
        case userId
        case quizBankId
        case timestamp
        case selectedQuestionIds
        case scores
        case resultCategory
        case resultType
    }
    
    // Convert to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "quizBankId": quizBankId,
            "timestamp": Timestamp(date: timestamp),
            "selectedQuestionIds": selectedQuestionIds,
            "scores": scores,
            "resultCategory": resultCategory,
            "resultType": resultType
        ]
    }
    
    // Create from QuizResult and user data
    static func from(
        userId: String,
        quizBankId: String,
        selectedQuestionIds: [String],
        scores: [String: Int],
        result: QuizResult
    ) -> UserQuizResult {
        // Determine result type and categories
        let resultType: String
        let resultCategory: [String]
        
        if result.isTied {
            resultType = "mixed"
            resultCategory = result.tiedCategories.sorted()
        } else {
            resultType = "single"
            resultCategory = [result.moodCategory]
        }
        
        return UserQuizResult(
            userId: userId,
            quizBankId: quizBankId,
            timestamp: Date(),
            selectedQuestionIds: selectedQuestionIds,
            scores: scores,
            resultCategory: resultCategory,
            resultType: resultType
        )
    }
}