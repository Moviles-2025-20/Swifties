//
//  QuizQuestion.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/11/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Quiz Question Model
struct QuizQuestion: Identifiable, Codable {
    @DocumentID var id: String?
    var text: String
    var imageUrl: String?
    var options: [QuizOption]
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case imageUrl
        case options
    }
}

// MARK: - Quiz Option Model
struct QuizOption: Codable, Identifiable {
    var text: String
    var category: String
    var points: Int
    
    // Computed property for Identifiable
    var id: String { text }
    
    enum CodingKeys: String, CodingKey {
        case text
        case category
        case points
    }
}

// MARK: - Quiz Result Model
struct QuizResult {
    let moodCategory: String  // DISPLAY name
    let rawCategory: String   // Actual category key
    let isTied: Bool
    let tiedCategories: [String]
    let emoji: String
    let description: String
    let totalScore: Int
    
    // FIXED: Simple dictionary declarations (no complex type inference)
    
    static let categoryEmojis: [String: String] = [
        "creative": "🎨",
        "social_planner": "🎉",
        "cultural_explorer": "📚",
        "chill": "😌"
    ]
    
    static let categoryIcons: [String: String] = [
        "creative": "paintbrush.fill",
        "social_planner": "person.3.fill",
        "cultural_explorer": "book.fill",
        "chill": "leaf.fill"
    ]
    
    static let categoryColors: [String: Color] = [
        "creative": Color.purple,
        "social_planner": Color.orange,
        "cultural_explorer": Color.blue,
        "chill": Color.green
    ]
    
    static let categoryDisplayNames: [String: String] = [
        "creative": "Creative",
        "social_planner": "Social Planner",
        "cultural_explorer": "Cultural Explorer",
        "chill": "Chill"
    ]
    
    static let categoryDescriptions: [String: String] = [
        "creative": "You're a creative soul! You see beauty in aesthetics and love expressing yourself through art and design.",
        "social_planner": "You're the life of the party! You thrive in social settings and love bringing people together.",
        "cultural_explorer": "You're curious and cultured! You love learning, exploring new ideas, and experiencing meaningful content.",
        "chill": "You're zen and peaceful! You value tranquility, nature, and taking time to relax and recharge."
    ]
    
    static let categoryPriority: [String] = [
        "social_planner",
        "creative",
        "cultural_explorer",
        "chill"
    ]
}

// MARK: - User Answer Model
struct UserAnswer: Codable {
    let questionId: String
    let selectedOptionId: String
    let category: String
    let points: Int
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case selectedOptionId = "selected_option_id"
        case category
        case points
        case timestamp
    }
}
