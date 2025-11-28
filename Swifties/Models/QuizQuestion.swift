// QuizModel.swift
// Swifties
// Created by Assistant

import Foundation
import FirebaseFirestore

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
struct QuizOption: Codable {
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
    let moodCategory: String
    let isTied: Bool
    let tiedCategories: [String]
    let emoji: String
    let description: String
    let totalScore: Int
    
    // Category emojis mapping - UPDATED for your 4 categories
    static let categoryEmojis: [String: String] = [
        "creative": "🎨",
        "social_planner": "🎉",
        "cultural_explorer": "📚",
        "chill": "😌"
    ]
    
    // Category descriptions - UPDATED for your 4 categories
    static let categoryDescriptions: [String: String] = [
        "creative": "You're a creative soul! You see beauty in aesthetics and love expressing yourself through art and design.",
        "social_planner": "You're the life of the party! You thrive in social settings and love bringing people together.",
        "cultural_explorer": "You're curious and cultured! You love learning, exploring new ideas, and experiencing meaningful content.",
        "chill": "You're zen and peaceful! You value tranquility, nature, and taking time to relax and recharge."
    ]
    
    // Priority order for 3+ way ties - UPDATED for your 4 categories
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