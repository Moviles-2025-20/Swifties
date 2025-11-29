//
//  MoodQuizViewModel.swift
//  Swifties
//
//  Fixed version with proper "Take Again" functionality
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
class MoodQuizViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var questions: [QuizQuestion] = []
    @Published var userAnswers: [UserAnswer] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var showResult: Bool = false
    @Published var quizResult: QuizResult?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var dataSource: DataSource = .none
    @Published var isRefreshing: Bool = false
    @Published var hasPendingUpload: Bool = false
    @Published var isSavingResult: Bool = false
    
    // FIX: Store category scores separately for proper reconstruction
    @Published private(set) var categoryScores: [String: Int] = [:]
    
    
    // Track if user has started answering questions
    private var hasLoggedQuizStart = false

    // MARK: - Services
    
    private let networkService = QuizNetworkService.shared
    private let storageService = QuizStorageService.shared
    private let cacheService = QuizCacheService.shared
    private let syncService = QuizSyncService.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(userAnswers.count) / Double(questions.count)
    }
    
    var isLastQuestion: Bool {
        return currentQuestionIndex == questions.count - 1
    }
    
    // MARK: - Data Source Enum
    
    enum DataSource {
        case memoryCache
        case localStorage
        case network
        case none
    }
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Check for pending uploads on init
        hasPendingUpload = storageService.hasPendingResults()
        
        // Observe sync completion to update UI
        NotificationCenter.default.publisher(for: .quizSyncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📢 [VIEWMODEL] Received sync completion notification")
                self?.hasPendingUpload = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Quiz
    
    func loadQuiz() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please sign in to take the quiz"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("\n=== LOADING QUIZ FOR USER: \(userId) ===")
        
        // STEP 1: Check if user wants to retake the quiz
        if storageService.wantsRetake(userId: userId) {
            print("🔄 User wants retake - clearing old result...")
            clearQuizState()
            storageService.clearQuizState(userId: userId)
            // CRITICAL: Clear the retake flag so it doesn't loop
            storageService.setWantsRetake(userId: userId, value: false)
            
            // Load questions and show quiz
            await loadQuizQuestions()
            isLoading = false
            return
        }
        
        // STEP 2: Check memory cache for existing result
        if let cached = cacheService.getCachedResult(userId: userId) {
            print("✅ [MEMORY CACHE] Found cached result")
            quizResult = cached.quizResult
            
            // CRITICAL FIX: Load scores from cached UserQuizResult
            categoryScores = cached.userQuizResult.scores
            
            showResult = true
            dataSource = .memoryCache
            isLoading = false
            return
        }
        
        // STEP 3: Check local storage (Realm) for existing result
        if let stored = await storageService.loadQuizResult(userId: userId) {
            print("✅ [LOCAL STORAGE] Found stored result")
            quizResult = stored.result
            
            // CRITICAL FIX: Load scores from stored UserQuizResult
            categoryScores = stored.userQuizResult.scores
            
            showResult = true
            dataSource = .localStorage
            
            // Cache it in memory for next time
            cacheService.cacheQuizResult(
                userId: userId,
                result: stored.result,
                userQuizResult: stored.userQuizResult
            )
            
            // Try to refresh from network in background
            Task {
                await refreshFromNetwork()
            }
            
            isLoading = false
            return
        }
        
        // STEP 4: Load quiz questions (check cache → storage → network)
        await loadQuizQuestions()
        
        isLoading = false
    }
    
    // MARK: - Load Quiz Questions
    
    private func loadQuizQuestions() async {
        print("\n--- LOADING QUIZ QUESTIONS ---")
        
        // ALWAYS select random questions, regardless of source
        var allQuestions: [QuizQuestion]? = nil
        
        // Try memory cache first
        if let cached = QuizQuestionsCache.shared.getCachedQuestions() {
            print("✅ [MEMORY CACHE] Found \(cached.count) cached questions")
            allQuestions = cached
            dataSource = .memoryCache
        }
        // Try SQLite local storage
        else if let stored = storageService.loadQuestions() {
            print("✅ [SQLITE STORAGE] Found \(stored.count) stored questions")
            allQuestions = stored
            dataSource = .localStorage
            
            // Cache in memory for next time
            QuizQuestionsCache.shared.cacheQuestions(stored)
            
            // Try to refresh from network in background
            if networkMonitor.isConnected {
                Task {
                    await refreshQuestionsFromNetwork()
                }
            }
        }
        // Must fetch from network
        else {
            guard networkMonitor.isConnected else {
                errorMessage = "No internet connection and no cached quiz available"
                return
            }
            
            await fetchQuestionsFromNetwork()
            return // fetchQuestionsFromNetwork() handles selection
        }
        
        // Select 5 random questions from the pool
        if let all = allQuestions {
            questions = selectRandomQuestions(from: all)
        }
    }
    
    // MARK: - Select Random Questions
    
    private func selectRandomQuestions(from allQuestions: [QuizQuestion]) -> [QuizQuestion] {
        let questionCount = 5
        
        guard allQuestions.count > questionCount else {
            print("⚠️ Not enough questions available (\(allQuestions.count)). Using all questions.")
            return allQuestions
        }
        
        // Shuffle and take 5
        let selected = Array(allQuestions.shuffled().prefix(questionCount))
        print("✅ Selected \(selected.count) random questions from \(allQuestions.count) available")
        
        return selected
    }
    
    private func fetchQuestionsFromNetwork() async {
        print("🌐 [NETWORK] Fetching questions from Firestore...")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            networkService.fetchQuizQuestions { [weak self] result in
                Task { @MainActor in
                    defer { continuation.resume() }
                    
                    switch result {
                    case .success(let fetchedQuestions):
                        print("✅ [NETWORK] Fetched \(fetchedQuestions.count) questions")
                        
                        // Select random 5 questions for display
                        self?.questions = self?.selectRandomQuestions(from: fetchedQuestions) ?? []
                        self?.dataSource = .network
                        
                        // Save ALL questions to storage and cache (not just the random 5)
                        self?.storageService.saveQuestions(fetchedQuestions)
                        QuizQuestionsCache.shared.cacheQuestions(fetchedQuestions)
                        
                    case .failure(let error):
                        print("❌ [NETWORK] Failed to fetch questions: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to load quiz: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func refreshQuestionsFromNetwork() async {
        isRefreshing = true
        await fetchQuestionsFromNetwork()
        isRefreshing = false
    }
    
    private func refreshFromNetwork() async {
        guard networkMonitor.isConnected else { return }
        
        isRefreshing = true
        // Could fetch updated result from Firestore here if needed
        isRefreshing = false
    }
    
    // MARK: - Select Answer

    func selectAnswer(_ option: QuizOption) {
        guard let questionId = questions[currentQuestionIndex].id else {
            print("⚠️ Cannot select answer - question has no ID")
            return
        }
        
        let answer = UserAnswer(
            questionId: questionId,
            selectedOptionId: option.id,
            category: option.category,
            points: option.points,
            timestamp: Date()
        )
        
        // Update or replace answer for current question
        if userAnswers.indices.contains(currentQuestionIndex) {
            userAnswers[currentQuestionIndex] = answer
        } else {
            userAnswers.append(answer)
        }
        
        // !!!! LOG FIRST QUESTION ANSWERED (quiz actually started)
        if !hasLoggedQuizStart {
            AnalyticsService.shared.logMoodQuizStarted()
            hasLoggedQuizStart = true
            print("[ANALYTICS] Quiz started - first question answered")
        }
        
        print("✅ Selected answer: \(option.text) → \(option.category) (\(option.points) pts)")
    }
    
    // MARK: - Calculate Result

    func calculateResult() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        print("\n=== CALCULATING QUIZ RESULT ===")
        print("User Answers: \(userAnswers.count)")
        
        // Calculate category scores
        var scores: [String: Int] = [
            "creative": 0,
            "social_planner": 0,
            "cultural_explorer": 0,
            "chill": 0
        ]
        
        for answer in userAnswers {
            scores[answer.category, default: 0] += answer.points
            print("  \(answer.category): +\(answer.points) pts")
        }
        
        // CRITICAL FIX: Store scores in published property
        categoryScores = scores
        
        print("\nFinal Scores:")
        scores.forEach { print("  \($0.key): \($0.value) pts") }
        
        // Determine result
        let totalScore = scores.values.reduce(0, +)
        let maxScore = scores.values.max() ?? 0
        let topCategories = scores.filter { $0.value == maxScore }.map { $0.key }
        
        let isTied = topCategories.count > 1
        let rawCategory: String
        let displayCategory: String
        
        if isTied {
            // Sort by priority
            let sortedByPriority = topCategories.sorted { cat1, cat2 in
                let idx1 = QuizResult.categoryPriority.firstIndex(of: cat1) ?? Int.max
                let idx2 = QuizResult.categoryPriority.firstIndex(of: cat2) ?? Int.max
                return idx1 < idx2
            }
            
            rawCategory = sortedByPriority.first!
            
            let displayNames = sortedByPriority.compactMap {
                QuizResult.categoryDisplayNames[$0]
            }
            displayCategory = displayNames.joined(separator: " & ")
        } else {
            rawCategory = topCategories.first!
            displayCategory = QuizResult.categoryDisplayNames[rawCategory] ?? rawCategory
        }
        
        let result = QuizResult(
            moodCategory: displayCategory,
            rawCategory: rawCategory,
            isTied: isTied,
            tiedCategories: topCategories.sorted(),
            emoji: QuizResult.categoryEmojis[rawCategory] ?? "🎯",
            description: QuizResult.categoryDescriptions[rawCategory] ?? "",
            totalScore: totalScore
        )
        
        print("\n RESULT:")
        print("  Category: \(result.moodCategory) (raw: \(result.rawCategory))")
        print("  Is Tied: \(result.isTied)")
        print("  Tied Categories: \(result.tiedCategories)")
        print("  Total Score: \(result.totalScore)")
        
        // !!!! LOG QUIZ COMPLETION (user clicked Finish)
        AnalyticsService.shared.logMoodQuizCompleted(
            resultCategory: result.rawCategory,
            totalScore: result.totalScore,
            isTied: result.isTied
        )
        print(" [ANALYTICS] Quiz completed")
        
        // Create UserQuizResult
        let selectedQuestionIds = userAnswers.compactMap { $0.questionId }
        let userQuizResult = UserQuizResult.from(
            userId: userId,
            quizBankId: "lOhEPYC8ci9lBEo08G47",
            selectedQuestionIds: selectedQuestionIds,
            scores: scores,
            result: result
        )
        
        // Auto-save result
        Task {
            await saveQuizResult(result: result, userQuizResult: userQuizResult)
        }
        
        // Show result
        quizResult = result
        showResult = true
    }
    
    // MARK: - Save Quiz Result
    
    private func saveQuizResult(result: QuizResult, userQuizResult: UserQuizResult) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isSavingResult = true
        print("\n [SAVING] Auto-saving quiz result...")
        
        // 1. Save to memory cache
        cacheService.cacheQuizResult(
            userId: userId,
            result: result,
            userQuizResult: userQuizResult
        )
        
        // 2. Save to local storage (Realm)
        storageService.saveQuizResult(
            userId: userId,
            result: result,
            userQuizResult: userQuizResult
        )
        
        // 3. Mark that user has a result
        storageService.setHasResult(userId: userId, value: true)
        
        // 4. Try to upload to Firestore if online
        if networkMonitor.isConnected {
            print("[ONLINE] Uploading to Firestore...")
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                networkService.uploadQuizResult(userQuizResult) { [weak self] result in
                    Task { @MainActor in
                        defer {
                            self?.isSavingResult = false
                            continuation.resume()
                        }
                        
                        switch result {
                        case .success:
                            print("✅ [FIRESTORE] Result uploaded successfully")
                            
                        case .failure(let error):
                            print("❌ [FIRESTORE] Upload failed: \(error.localizedDescription)")
                            print("Saving to pending uploads for later sync...")
                            self?.storageService.savePendingResult(userQuizResult)
                            self?.hasPendingUpload = true
                        }
                    }
                }
            }
        } else {
            print(" [OFFLINE] Saving to pending uploads...")
            storageService.savePendingResult(userQuizResult)
            hasPendingUpload = true
            isSavingResult = false
        }
        
        print("✅ [SAVED] Quiz result saved successfully")
    }
    
    // MARK: - Get Category Scores
    
    func getCategoryScores() -> [String: Int] {
        // CRITICAL FIX: Return the stored scores, not recalculate
        if !categoryScores.isEmpty {
            return categoryScores
        }
        
        // Fallback: calculate from answers if available
        if !userAnswers.isEmpty {
            var scores: [String: Int] = [
                "creative": 0,
                "social_planner": 0,
                "cultural_explorer": 0,
                "chill": 0
            ]
            
            for answer in userAnswers {
                scores[answer.category, default: 0] += answer.points
            }
            
            categoryScores = scores
            return scores
        }
        
        // Last resort: return empty scores
        return [
            "creative": 0,
            "social_planner": 0,
            "cultural_explorer": 0,
            "chill": 0
        ]
    }
    
    // MARK: - Retake Quiz - FIXED!
    
    func handleTakeAgainAction() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("\n🔄 [RETAKE] User wants to retake quiz")
        
        // STEP 1: Set the retake flag FIRST
        storageService.setWantsRetake(userId: userId, value: true)
        
        // STEP 2: Clear all cached/stored results
        print("XXXX [RETAKE] Clearing cache and storage...")
        cacheService.clearCache(userId: userId)
        storageService.deleteQuizResult(userId: userId)
        storageService.setHasResult(userId: userId, value: false)
        
        // STEP 3: Clear local state
        print("XXXXX [RETAKE] Clearing local state...")
        clearQuizState()
        
        // STEP 4: Reload quiz (will detect wantsRetake flag and load questions)
        print(" [RETAKE] Reloading quiz...")
        await loadQuiz()
        
        print(" [RETAKE] Quiz ready for retake!")
    }
    
    private func clearQuizState() {
        userAnswers.removeAll()
        currentQuestionIndex = 0
        showResult = false
        quizResult = nil
        categoryScores.removeAll()
        errorMessage = nil
        hasLoggedQuizStart = false
    }
}

// MARK: - Quiz Questions Cache (Separate from Results)

class QuizQuestionsCache {
    static let shared = QuizQuestionsCache()
    
    private let cache = NSCache<NSString, CachedQuestionsWrapper>()
    private var cacheTimestamp: Date?
    private let cacheExpirationMinutes = 60.0
    
    private init() {
        cache.countLimit = 1
    }
    
    func cacheQuestions(_ questions: [QuizQuestion]) {
        let wrapper = CachedQuestionsWrapper(questions: questions)
        cache.setObject(wrapper, forKey: "quiz_questions" as NSString)
        cacheTimestamp = Date()
        print("✅ Cached \(questions.count) quiz questions")
    }
    
    func getCachedQuestions() -> [QuizQuestion]? {
        if let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) > cacheExpirationMinutes * 60 {
            clearCache()
            return nil
        }
        
        return cache.object(forKey: "quiz_questions" as NSString)?.questions
    }
    
    func clearCache() {
        cache.removeAllObjects()
        cacheTimestamp = nil
    }
}

class CachedQuestionsWrapper {
    let questions: [QuizQuestion]
    
    init(questions: [QuizQuestion]) {
        self.questions = questions
    }
}
