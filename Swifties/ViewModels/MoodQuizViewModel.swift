//
//  MoodQuizViewModel.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/11/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class MoodQuizViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var questions: [QuizQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var selectedAnswers: [String: UserAnswer] = [:] // questionId: answer
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var quizResult: QuizResult?
    @Published var showResult: Bool = false
    
    // MARK: - Private Properties
    private let db = Firestore.firestore(database: "default")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(questions.count)
    }
    
    var canGoNext: Bool {
        guard let currentQuestionId = currentQuestion?.id else { return false }
        return selectedAnswers[currentQuestionId] != nil
    }
    
    var isLastQuestion: Bool {
        return currentQuestionIndex == questions.count - 1
    }
    
    // MARK: - Fetch Questions from Firebase
    func fetchQuestions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("------->>>>> Fetching quiz questions from Firebase...")
            
            // Fetch from the document that contains the questions array
            let docRef = db.collection("quiz_questions").document("lOhEPYC8ci9lBEo08G47")
            let document = try await docRef.getDocument()
            
            guard let data = document.data(),
                  let questionsArray = data["questions"] as? [[String: Any]] else {
                print("!!!!!!! No questions found in document")
                errorMessage = "No quiz questions available at the moment"
                isLoading = false
                return
            }
            
            // Parse questions manually since they're in a nested array
            var fetchedQuestions: [QuizQuestion] = []
            
            for questionData in questionsArray {
                guard let id = questionData["id"] as? String,
                      let text = questionData["text"] as? String,
                      let optionsArray = questionData["options"] as? [[String: Any]] else {
                    continue
                }
                
                let imageUrl = questionData["imageUrl"] as? String
                
                var options: [QuizOption] = []
                for optionData in optionsArray {
                    guard let optionText = optionData["text"] as? String,
                          let category = optionData["category"] as? String,
                          let points = optionData["points"] as? Int else {
                        continue
                    }
                    
                    options.append(QuizOption(text: optionText, category: category, points: points))
                }
                
                fetchedQuestions.append(QuizQuestion(id: id, text: text, imageUrl: imageUrl, options: options))
            }
            
            if fetchedQuestions.isEmpty {
                print("!!!!!!! No valid questions parsed")
                errorMessage = "Failed to parse quiz questions"
            } else {
                // Randomly select 5 questions from the pool
                questions = Array(fetchedQuestions.shuffled().prefix(5))
                print("✅ Loaded \(questions.count) random questions from \(fetchedQuestions.count) total")
            }
            
            isLoading = false
        } catch {
            print("❌ Error fetching questions: \(error.localizedDescription)")
            errorMessage = "Failed to load quiz questions: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Answer Selection
    func selectAnswer(option: QuizOption) {
        guard let questionId = currentQuestion?.id else { return }
        
        let answer = UserAnswer(
            questionId: questionId,
            selectedOptionId: option.text, // Using text as ID since options don't have separate IDs
            category: option.category,
            points: option.points,
            timestamp: Date()
        )
        
        selectedAnswers[questionId] = answer
        print("✅ Answer selected: \(option.text) (\(option.category): +\(option.points))")
    }
    
    func isOptionSelected(_ optionText: String) -> Bool {
        guard let questionId = currentQuestion?.id else { return false }
        return selectedAnswers[questionId]?.selectedOptionId == optionText
    }
    
    // MARK: - Navigation
    func goToNextQuestion() {
        guard canGoNext else { return }
        
        if isLastQuestion {
            // Calculate result
            calculateResult()
        } else {
            currentQuestionIndex += 1
        }
    }
    
    func goToPreviousQuestion() {
        guard currentQuestionIndex > 0 else { return }
        currentQuestionIndex -= 1
    }
    
    // MARK: - Calculate Result
    private func calculateResult() {
        print("\n📊 Calculating quiz result...")
        
        // Count points per category
        var categoryScores: [String: Int] = [:]
        var totalScore = 0
        
        for answer in selectedAnswers.values {
            categoryScores[answer.category, default: 0] += answer.points
            totalScore += answer.points
        }
        
        print("Category scores: \(categoryScores)")
        
        // Find max score
        guard let maxScore = categoryScores.values.max() else {
            print("❌ No scores found")
            return
        }
        
        // Find all categories with max score (ties)
        let topCategories = categoryScores.filter { $0.value == maxScore }.map { $0.key }
        
        print("Top categories: \(topCategories) with score: \(maxScore)")
        
        // Determine result based on tie rules
        let result: QuizResult
        
        if topCategories.count == 1 {
            // No tie - single winner
            let category = topCategories[0]
            result = QuizResult(
                moodCategory: category,
                isTied: false,
                tiedCategories: [],
                emoji: QuizResult.categoryEmojis[category] ?? "😊",
                description: QuizResult.categoryDescriptions[category] ?? "¡Resultado único!",
                totalScore: totalScore
            )
            print("✅ Result: Single winner - \(category)")
            
        } else if topCategories.count == 2 {
            // 2-way tie - mixed result
            let mixedCategory = topCategories.sorted().joined(separator: " + ")
            let mixedEmoji = topCategories.compactMap { QuizResult.categoryEmojis[$0] }.joined()
            let mixedDescription = "Eres una mezcla perfecta entre \(topCategories[0]) y \(topCategories[1]). Tienes cualidades de ambos mundos."
            
            result = QuizResult(
                moodCategory: mixedCategory,
                isTied: true,
                tiedCategories: topCategories,
                emoji: mixedEmoji,
                description: mixedDescription,
                totalScore: totalScore
            )
            print("✅ Result: 2-way tie - \(mixedCategory)")
            
        } else {
            // 3+ way tie - use priority
            let winner = QuizResult.categoryPriority.first { topCategories.contains($0) } ?? topCategories[0]
            
            result = QuizResult(
                moodCategory: winner,
                isTied: true,
                tiedCategories: topCategories,
                emoji: QuizResult.categoryEmojis[winner] ?? "😊",
                description: (QuizResult.categoryDescriptions[winner] ?? "") + " (Múltiples afinidades detectadas)",
                totalScore: totalScore
            )
            print("✅ Result: 3+ way tie resolved to \(winner) by priority")
        }
        
        quizResult = result
        showResult = true
    }
    
    // MARK: - Save Result
    func saveResultToFirebase() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let result = quizResult else {
            print("❌ Cannot save: No user or result")
            errorMessage = "Unable to save result. Please try again."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate category scores
            var categoryScores: [String: Int] = [:]
            for answer in selectedAnswers.values {
                categoryScores[answer.category, default: 0] += answer.points
            }
            
            // Get selected question IDs in order
            let selectedQuestionIds = questions.map { $0.id ?? "" }
            
            // Create UserQuizResult
            let userQuizResult = UserQuizResult.from(
                userId: uid,
                quizBankId: "personality_v1",  // You can make this dynamic if needed
                selectedQuestionIds: selectedQuestionIds,
                scores: categoryScores,
                result: result
            )
            
            // Save to quiz_answers collection
            let resultData = userQuizResult.toFirestoreData()
            try await db.collection("quiz_answers").addDocument(data: resultData)
            
            print("✅ Quiz result saved successfully")
            print("   User: \(uid)")
            print("   Quiz ID: personality_v1")
            print("   Selected Questions: \(selectedQuestionIds)")
            print("   Scores: \(categoryScores)")
            print("   Result Category: \(userQuizResult.resultCategory)")
            print("   Result Type: \(userQuizResult.resultType)")
            
            // Update user stats
            try await db.collection("users").document(uid).updateData([
                "stats.last_quiz_date": FieldValue.serverTimestamp(),
                "stats.total_quizzes": FieldValue.increment(Int64(1))
            ])
            
            isLoading = false
            
        } catch {
            print("❌ Error saving result: \(error.localizedDescription)")
            errorMessage = "Failed to save result. Please try again."
            isLoading = false
        }
    }
    
    // MARK: - Reset Quiz
    func resetQuiz() {
        currentQuestionIndex = 0
        selectedAnswers.removeAll()
        quizResult = nil
        showResult = false
    }
}
