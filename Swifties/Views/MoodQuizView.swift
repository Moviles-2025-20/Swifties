//
//  MoodQuizView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 26/11/25.
//
import SwiftUI

struct MoodQuizView: View {
    @StateObject private var viewModel = MoodQuizViewModel()
    @ObservedObject private var networkMonitor = NetworkMonitorService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showOfflineAlert = false
    @State private var offlineAlertMessage = ""
    @State private var showNews: Bool = false
    
    // MARK: - Computed Properties for Data Source Indicator
    
    private var dataSourceIcon: String {
        switch viewModel.dataSource {
        case .memoryCache: return "memorychip"
        case .localStorage: return "internaldrive"
        case .network: return "wifi"
        case .none: return "questionmark"
        }
    }
    
    private var dataSourceText: String {
        switch viewModel.dataSource {
        case .memoryCache: return "Memory Cache"
        case .localStorage: return "Local Storage"
        case .network: return "Updated from Network"
        case .none: return ""
        }
    }
    
    private var shouldShowOfflineBanner: Bool {
        return !networkMonitor.isConnected && (!viewModel.questions.isEmpty || viewModel.showResult)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: "Mood Quiz",
                        showNotificationButton: true,
                        showBackButton: true,
                        onNotificationTap: { showNews = true },
                        onBackTap: { dismiss() }
                    )
                    
                    buildBanners()
                    buildDataSourceIndicator()
                    buildMainContent()
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .alert("Connection Required", isPresented: $showOfflineAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(offlineAlertMessage)
            }
            .task {
                await viewModel.loadQuiz()
            }
            .navigationDestination(isPresented: $showNews) {
                NewsView()
            }
        }
    }
    
    // MARK: - Banner Views
    
    @ViewBuilder
    private func buildBanners() -> some View {
        VStack(spacing: 4) {
            // Connection status banner (only when there IS data)
            if shouldShowOfflineBanner {
                buildOfflineBanner()
            }
            
            // Pending upload banner
            if viewModel.hasPendingUpload {
                buildPendingUploadBanner()
            }
            
            // Saving indicator banner (NEW!)
            if viewModel.isSavingResult {
                buildSavingBanner()
            }
        }
    }
    
    private func buildOfflineBanner() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            Text("Offline - Your progress is saved locally")
                .font(.callout)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func buildPendingUploadBanner() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.blue)
            Text("Result saved - will sync when online")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func buildSavingBanner() -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(networkMonitor.isConnected ? "Saving result..." : "Saving locally...")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private func buildDataSourceIndicator() -> some View {
        if !viewModel.isLoading && viewModel.dataSource != .none {
            HStack {
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: dataSourceIcon)
                        .foregroundColor(.secondary)
                    Text(dataSourceText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Updating...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Main Content Router
    
    @ViewBuilder
    private func buildMainContent() -> some View {
        if viewModel.isLoading {
            loadingView
        } else if !networkMonitor.isConnected && viewModel.questions.isEmpty && !viewModel.showResult {
            offlineNoCacheView
        } else if let error = viewModel.errorMessage {
            errorView(error: error)
        } else if viewModel.showResult, let result = viewModel.quizResult {
            resultView(result: result)
        } else if !viewModel.questions.isEmpty {
            questionView
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading quiz...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Offline No Cache View
    
    private var offlineNoCacheView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Internet Connection")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No cached or stored data available")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Please connect to the internet and try again to load the mood quiz")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                if !networkMonitor.isConnected {
                    offlineAlertMessage = "Still no internet connection - Please check your network settings"
                    showOfflineAlert = true
                } else {
                    Task {
                        await viewModel.loadQuiz()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Error View
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: getErrorIcon(for: error))
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Quiz")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            buildErrorButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private func buildErrorButton() -> some View {
        VStack(spacing: 12) {
            if !networkMonitor.isConnected {
                Text("Please connect to the internet and try again")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                if !networkMonitor.isConnected {
                    offlineAlertMessage = "Cannot retry - No internet connection available"
                    showOfflineAlert = true
                } else {
                    Task { await viewModel.loadQuiz() }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(networkMonitor.isConnected ? Color.blue : Color.gray.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 8)
        }
    }
    
    private func getErrorIcon(for error: String) -> String {
        if error.contains("internet") || error.contains("connection") || error.contains("download") {
            return "wifi.slash"
        } else if error.contains("questions") || error.contains("parse") {
            return "questionmark.circle"
        } else {
            return "exclamationmark.triangle"
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Ready to discover your mood?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Answer a few questions and find activities that match your vibe!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Question View
    
    private var questionView: some View {
        VStack(spacing: 0) {
            buildProgressIndicator()
            buildPaginatedQuestions()
            buildNavigationButtons()
        }
    }
    
    private func buildProgressIndicator() -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: viewModel.progress)
                .tint(Color("appRed"))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private func buildPaginatedQuestions() -> some View {
        TabView(selection: $viewModel.currentQuestionIndex) {
            ForEach(Array(viewModel.questions.enumerated()), id: \.offset) { index, question in
                buildQuestionPage(question: question, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: viewModel.currentQuestionIndex)
    }
    
    private func buildQuestionPage(question: QuizQuestion, index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(question.text)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        OptionCard(
                            option: option,
                            isSelected: viewModel.userAnswers.indices.contains(index) &&
                            viewModel.userAnswers[index].selectedOptionId == option.id,
                            onTap: { viewModel.selectAnswer(option) }
                        )
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func buildNavigationButtons() -> some View {
        HStack(spacing: 16) {
            if viewModel.currentQuestionIndex > 0 {
                buildBackButton()
            }
            
            buildNextButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.95))
    }
    
    private func buildBackButton() -> some View {
        Button {
            withAnimation {
                viewModel.currentQuestionIndex -= 1
            }
        } label: {
            HStack {
                Image(systemName: "arrow.left")
                Text("Back")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color("appRed"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("appRed"), lineWidth: 2)
            )
        }
    }
    
    private func buildNextButton() -> some View {
        Button {
            if viewModel.isLastQuestion {
                // Auto-save happens in calculateResult()
                viewModel.calculateResult()
            } else {
                withAnimation {
                    viewModel.currentQuestionIndex += 1
                }
            }
        } label: {
            HStack {
                Text(viewModel.isLastQuestion ? "Finish" : "Next")
                Image(systemName: viewModel.isLastQuestion ? "checkmark" : "arrow.right")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.userAnswers.indices.contains(viewModel.currentQuestionIndex) ? Color("appRed") : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!viewModel.userAnswers.indices.contains(viewModel.currentQuestionIndex))
    }
    
    // MARK: - Result View
    
    private func resultView(result: QuizResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                buildResultCard(result: result)
                    .padding(.horizontal)
                    .padding(.top, 32)
            }
            .padding(.bottom, 32)
        }
    }
    
    private func buildResultCard(result: QuizResult) -> some View {
        VStack(spacing: 20) {
            categoryIconsView(for: result)
            buildResultBadge(result: result)
            buildCategoryNames(result: result)
            buildDescription(result: result)
            
            Divider()
                .padding(.vertical, 8)
            
            buildScoresSection()
            
            Divider()
                .padding(.vertical, 8)
            
            buildActionButtons()
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func buildResultBadge(result: QuizResult) -> some View {
        Text(result.isTied ? "MIXED RESULT" : "SINGLE RESULT")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color.blue.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
    }
    
    @ViewBuilder
    private func buildCategoryNames(result: QuizResult) -> some View {
        if result.isTied {
            VStack(spacing: 8) {
                ForEach(result.tiedCategories, id: \.self) { category in
                    if let displayName = QuizResult.categoryDisplayNames[category],
                       let color = QuizResult.categoryColors[category] {
                        Text(displayName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(color)
                    }
                }
            }
        } else {
            Text(result.moodCategory)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(QuizResult.categoryColors[result.rawCategory] ?? .primary)
        }
    }
    
    private func buildDescription(result: QuizResult) -> some View {
        Text(result.description)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
    }
    
    private func buildScoresSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Scores")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
            
            let sortedScores = viewModel.getCategoryScores().sorted(by: { $0.value > $1.value })
            ForEach(sortedScores, id: \.key) { category, score in
                ScoreBar(category: category, score: score, maxScore: 25)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func buildActionButtons() -> some View {
        VStack(spacing: 12) {
            buildRetakeButton()
            // REMOVED: buildDoneButton() - auto-save handles everything!
        }
    }
    
    private func buildRetakeButton() -> some View {
        Button {
            Task {
                await viewModel.handleTakeAgainAction()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Take Quiz Again")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundColor(Color("appRed"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("appRed"), lineWidth: 2)
            )
        }
        .disabled(viewModel.isLoading || viewModel.isSavingResult)
    }
    
    // MARK: - Category Icons View
    
    @ViewBuilder
    private func categoryIconsView(for result: QuizResult) -> some View {
        if result.isTied {
            HStack(spacing: 16) {
                ForEach(result.tiedCategories, id: \.self) { category in
                    buildCategoryIcon(category: category, size: 80)
                }
            }
        } else {
            buildCategoryIcon(category: result.rawCategory, size: 120)
        }
    }
    
    @ViewBuilder
    private func buildCategoryIcon(category: String, size: CGFloat) -> some View {
        if let icon = QuizResult.categoryIcons[category],
           let color = QuizResult.categoryColors[category] {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: size, height: size)
                
                Image(systemName: icon)
                    .font(.system(size: size / 2))
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Option Card Component

struct OptionCard: View {
    let option: QuizOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                buildSelectionCircle()
                buildOptionText()
                Spacer()
            }
            .padding(16)
            .background(isSelected ? Color.blue.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? Color.blue.opacity(0.1) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func buildSelectionCircle() -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                .frame(width: 24, height: 24)
            
            if isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func buildOptionText() -> some View {
        Text(option.text)
            .font(.system(size: 16))
            .foregroundColor(isSelected ? Color.blue.opacity(0.9) : .primary)
            .fontWeight(isSelected ? .semibold : .regular)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Score Bar Component

struct ScoreBar: View {
    let category: String
    let score: Int
    let maxScore: Int
    
    var body: some View {
        VStack(spacing: 6) {
            buildScoreHeader()
            buildProgressBar()
        }
    }
    
    private func buildScoreHeader() -> some View {
        HStack {
            buildCategoryLabel()
            Spacer()
            buildScoreLabel()
        }
    }
    
    private func buildCategoryLabel() -> some View {
        HStack(spacing: 8) {
            if let icon = QuizResult.categoryIcons[category],
               let color = QuizResult.categoryColors[category] {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            if let displayName = QuizResult.categoryDisplayNames[category] {
                Text(displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }
    
    private func buildScoreLabel() -> some View {
        Text("\(score) pts")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }
    
    private func buildProgressBar() -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(QuizResult.categoryColors[category] ?? .blue)
                    .frame(width: geometry.size.width * CGFloat(score) / CGFloat(maxScore), height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#Preview {
    MoodQuizView()
}
