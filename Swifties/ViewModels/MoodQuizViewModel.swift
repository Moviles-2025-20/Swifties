//
//  MoodQuizViewModel.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/11/25.
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class MoodQuizViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var questions: [QuizQuestion] = []
    @Published var currentQuestionIndex = 0
    @Published var userAnswers: [UserAnswer] = []
    @Published var quizResult: QuizResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showResult = false
    @Published var dataSource: DataSource = .none
    @Published var isRefreshing = false
    @Published var hasPendingUpload = false
    
    enum DataSource {
        case none
        case memoryCache      // NSCache (result screen only)
        case localStorage     // SQLite (questions) or Realm (results)
        case network          // Firebase/Firestore
    }
    
    // MARK: - Services
    
    private let cacheService = QuizCacheService.shared
    private let storageService = QuizStorageService.shared
    private let networkService = QuizNetworkService.shared
    private let syncService = QuizSyncService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private let numberOfQuestions = 5
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var currentQuestion: QuizQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }
    
    var isLastQuestion: Bool {
        return currentQuestionIndex == questions.count - 1
    }
    
    // MARK: - Initialization
    
    init() {
        // Observe network changes for sync
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { [weak self] in
                        await self?.handleConnectivityRestored()
                    }
                }
            }
            .store(in: &cancellables)
        
        // CRITICAL FIX: Listen for sync completion notifications
        NotificationCenter.default.addObserver(
            forName: .quizSyncCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("✅ Quiz sync completed notification received")
            self?.hasPendingUpload = false
        }
        
        // CRITICAL FIX: Check for pending uploads on init
        checkForPendingUploads()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Check for Pending Uploads
    
    private func checkForPendingUploads() {
        hasPendingUpload = storageService.hasPendingResults()
        if hasPendingUpload {
            print("⚠️ Found pending quiz results to upload")
        }
    }
    
    // MARK: - Load Quiz (Startup Logic)
    
    func loadQuiz() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "No authenticated user"
            return
        }
        
        print("🎯 Loading quiz for user: \(userId)")
        
        // CRITICAL FIX: Check if we have pending uploads and try to sync first
        if storageService.hasPendingResults() && networkMonitor.isConnected {
            print("🔄 Found pending uploads, attempting sync before loading quiz...")
            await syncService.syncPendingResults()
            // Update the flag after sync attempt
            hasPendingUpload = storageService.hasPendingResults()
        }
        
        // Check if user wants to retake
        let wantsRetake = storageService.wantsRetake(userId: userId)
        
        if wantsRetake {
            print("🔄 User wants to retake quiz - loading questions")
            await loadQuestions()
            return
        }
        
        // Layer 1: Check NSCache for result
        if let cached = cacheService.getCachedResult(userId: userId) {
            print("✅ Loaded result from NSCache")
            quizResult = cached.quizResult
            showResult = true
            dataSource = .memoryCache
            return
        }
        
        // Layer 2: Check Realm for stored result
        if let stored = await storageService.loadQuizResult(userId: userId) {
            print("✅ Loaded result from Realm")
            quizResult = stored.result
            showResult = true
            dataSource = .localStorage
            
            // Cache in NSCache for next time
            cacheService.cacheQuizResult(
                userId: userId,
                result: stored.result,
                userQuizResult: stored.userQuizResult
            )
            
            return
        }
        
        // No result found - load questions for new quiz
        print("📝 No existing result - loading questions for new quiz")
        await loadQuestions()
    }
    
    // MARK: - Load Questions (Three-Layer Strategy)
    
    private func loadQuestions() async {
        isLoading = true
        errorMessage = nil
        
        // Layer 1: Try SQLite
        if let stored = storageService.loadQuestions(), !stored.isEmpty {
            print("✅ Loaded questions from SQLite")
            questions = selectRandomQuestions(from: stored)
            dataSource = .localStorage
            isLoading = false
            
            // Refresh in background if connected
            if networkMonitor.isConnected {
                Task {
                    await refreshQuestionsInBackground()
                }
            }
            
            return
        }
        
        // Layer 2: Try Firebase (with its own cache)
        if networkMonitor.isConnected {
            await fetchQuestionsFromNetwork()
        } else {
            // No questions anywhere and offline - block quiz
            isLoading = false
            errorMessage = "No quiz questions available. Please connect to the internet to download the quiz."
            dataSource = .none
            print("❌ BLOCKED: No questions in storage and no connectivity")
        }
    }
    
    private func fetchQuestionsFromNetwork() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            networkService.fetchQuizQuestions { [weak self] result in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.isLoading = false
                    
                    switch result {
                    case .success(let allQuestions):
                        if allQuestions.isEmpty {
                            self.errorMessage = "No quiz questions available"
                            self.dataSource = .none
                        } else {
                            // Save to SQLite for offline use
                            self.storageService.saveQuestions(allQuestions)
                            
                            // Select random subset
                            self.questions = self.selectRandomQuestions(from: allQuestions)
                            self.dataSource = .network
                            
                            print("✅ Loaded \(self.questions.count) questions from network")
                        }
                        
                    case .failure(let error):
                        self.errorMessage = "Failed to load quiz: \(error.localizedDescription)"
                        self.dataSource = .none
                        print("❌ Network error: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func refreshQuestionsInBackground() async {
        guard networkMonitor.isConnected else { return }
        
        isRefreshing = true
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            networkService.fetchQuizQuestions { [weak self] result in
                Task { @MainActor in
                    defer {
                        self?.isRefreshing = false
                        continuation.resume()
                    }
                    
                    guard let self = self else { return }
                    
                    if case .success(let allQuestions) = result, !allQuestions.isEmpty {
                        // Update SQLite with fresh questions
                        self.storageService.saveQuestions(allQuestions)
                        print("✅ Refreshed questions in background")
                    }
                }
            }
        }
    }
    
    private func selectRandomQuestions(from all: [QuizQuestion]) -> [QuizQuestion] {
        let count = min(numberOfQuestions, all.count)
        return Array(all.shuffled().prefix(count))
    }
    
    // MARK: - Answer Question
    
    func selectAnswer(_ option: QuizOption) {
        guard let questionId = currentQuestion?.id else { return }
        
        let answer = UserAnswer(
            questionId: questionId,
            selectedOptionId: option.id,
            category: option.category,
            points: option.points,
            timestamp: Date()
        )
        
        userAnswers.append(answer)
        print("✅ Answered question \(currentQuestionIndex + 1): \(option.category) (+\(option.points))")
        
        if isLastQuestion {
            calculateResult()
        } else {
            currentQuestionIndex += 1
        }
    }
    
    // MARK: - Calculate Result
    
    func calculateResult() {
        var scores: [String: Int] = [:]
        
        for answer in userAnswers {
            scores[answer.category, default: 0] += answer.points
        }
        
        let totalScore = scores.values.reduce(0, +)
        let maxScore = scores.values.max() ?? 0
        let topCategories = scores.filter { $0.value == maxScore }.map { $0.key }.sorted()
        
        let isTied = topCategories.count > 1
        let resultCategory: String
        
        if isTied {
            // Use priority for 3+ way ties
            if topCategories.count >= 3 {
                resultCategory = QuizResult.categoryPriority.first { topCategories.contains($0) } ?? topCategories[0]
            } else {
                resultCategory = topCategories[0]
            }
        } else {
            resultCategory = topCategories[0]
        }
        
        let displayName = QuizResult.categoryDisplayNames[resultCategory] ?? resultCategory
        let emoji = QuizResult.categoryEmojis[resultCategory] ?? "❓"
        let description = QuizResult.categoryDescriptions[resultCategory] ?? ""
        
        quizResult = QuizResult(
            moodCategory: displayName,
            rawCategory: resultCategory,
            isTied: isTied,
            tiedCategories: topCategories,
            emoji: emoji,
            description: description,
            totalScore: totalScore
        )
        
        showResult = true
        print("🎉 Quiz result: \(displayName) (tied: \(isTied))")
    }
    
    // MARK: - Handle Result Actions
    
    func handleDoneAction() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let result = quizResult else {
            return
        }
        
        let selectedQuestionIds = questions.compactMap { $0.id }
        var scores: [String: Int] = [:]
        
        for answer in userAnswers {
            scores[answer.category, default: 0] += answer.points
        }
        
        let userQuizResult = UserQuizResult.from(
            userId: userId,
            quizBankId: "quiz_bank_v1",
            selectedQuestionIds: selectedQuestionIds,
            scores: scores,
            result: result
        )
        
        // STEP 1: Always save UI-friendly result to Realm (for showing result screen later)
        storageService.saveQuizResult(userId: userId, result: result, userQuizResult: userQuizResult)
        print("💾 Saved UI result to Realm (emoji, description, etc.)")
        
        // STEP 2: Cache in NSCache for fast in-session access
        cacheService.cacheQuizResult(userId: userId, result: result, userQuizResult: userQuizResult)
        print("💾 Cached result in NSCache")
        
        // STEP 3: Set state flags
        storageService.setHasResult(userId: userId, value: true)
        storageService.setWantsRetake(userId: userId, value: false)
        
        // STEP 4: Handle UserQuizResult upload (the Firebase data model)
        if networkMonitor.isConnected {
            // Online: Upload UserQuizResult to Firebase
            isLoading = true
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                networkService.uploadQuizResult(userQuizResult) { [weak self] uploadResult in
                    Task { @MainActor in
                        defer {
                            self?.isLoading = false
                            continuation.resume()
                        }
                        
                        switch uploadResult {
                        case .success:
                            print("✅ UserQuizResult uploaded to Firebase")
                            // Remove any pending upload for this user (in case of retry)
                            self?.storageService.removePendingResult(userId: userId)
                            self?.hasPendingUpload = false
                            
                        case .failure(let error):
                            print("❌ Upload failed: \(error.localizedDescription)")
                            // Save UserQuizResult to UserDefaults for later upload
                            self?.storageService.savePendingResult(userQuizResult)
                            self?.hasPendingUpload = true
                        }
                    }
                }
            }
        } else {
            // Offline: Save UserQuizResult to UserDefaults for later upload
            storageService.savePendingResult(userQuizResult)
            hasPendingUpload = true
            print("📴 Offline: UserQuizResult saved to UserDefaults, will upload when online")
        }
    }
    
    func handleTakeAgainAction() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Clear result from caches
        cacheService.clearCache(userId: userId)
        storageService.deleteQuizResult(userId: userId)
        storageService.setWantsRetake(userId: userId, value: true)
        storageService.setHasResult(userId: userId, value: false)
        
        // Reset state
        quizResult = nil
        showResult = false
        currentQuestionIndex = 0
        userAnswers = []
        
        print("🔄 Retake initiated - loading new questions")
        
        // Load questions for new quiz
        await loadQuestions()
    }
    
    // MARK: - Connectivity Restored
    
    private func handleConnectivityRestored() async {
        // CRITICAL FIX: Always check storage, not just the local flag
        if storageService.hasPendingResults() {
            print("🌐 Connectivity restored - syncing pending results")
            await syncService.syncPendingResults()
            
            // Update flag after sync attempt
            hasPendingUpload = storageService.hasPendingResults()
        }
    }
    
    // MARK: - Reset Quiz
    
    func resetQuiz() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        cacheService.clearCache(userId: userId)
        storageService.deleteQuizResult(userId: userId)
        storageService.clearQuizState(userId: userId)
        
        questions = []
        currentQuestionIndex = 0
        userAnswers = []
        quizResult = nil
        showResult = false
        errorMessage = nil
        dataSource = .none
        hasPendingUpload = false
        
        print("🔄 Quiz reset complete")
    }
    
    
    // MARK: - Get Category Scores (for displaying in results)

    func getCategoryScores() -> [String: Int] {
        var scores: [String: Int] = [:]
        
        for answer in userAnswers {
            scores[answer.category, default: 0] += answer.points
        }
        
        return scores
    }
    
    // MARK: - Debug
    
    func debugCache() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for cache debug")
            return
        }
        
        print("\n" + String(repeating: "=", count: 50))
        print("MOOD QUIZ CACHE DEBUG")
        print(String(repeating: "=", count: 50))
        
        // Memory cache
        cacheService.debugCache(userId: userId)
        
        // Storage info
        let hasResult = storageService.hasResult(userId: userId)
        let wantsRetake = storageService.wantsRetake(userId: userId)
        let hasPending = storageService.hasPendingResults()
        
        print("💾 Storage State:")
        print("   Has Result: \(hasResult)")
        print("   Wants Retake: \(wantsRetake)")
        print("   Has Pending: \(hasPending)")
        
        // Current state
        print("📊 Current State:")
        print("   Questions loaded: \(questions.count)")
        print("   Current index: \(currentQuestionIndex)")
        print("   Showing result: \(showResult)")
        print("   Data source: \(dataSource)")
        print("   Network: \(networkMonitor.isConnected ? "Connected" : "Offline")")
        print("   Pending upload flag: \(hasPendingUpload)")
        
        if let error = errorMessage {
            print("   Error: \(error)")
        }
        
        print(String(repeating: "=", count: 50) + "\n")
    }
}
