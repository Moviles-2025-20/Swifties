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
    
    @State private var showOfflineSaveNotice = false
    
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
    
    // MARK: - Helper to determine if we should show offline banner
    private var shouldShowOfflineBanner: Bool {
        // Only show if offline AND we have content (questions or result)
        return !networkMonitor.isConnected && (!viewModel.questions.isEmpty || viewModel.showResult)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    CustomTopBar(
                        title: "Mood Quiz",
                        showNotificationButton: false,
                        onBackTap: { dismiss() }
                    )
                    
                    // Connection status banner - ONLY show when we have content
                    if shouldShowOfflineBanner {
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
                    
                    // Pending upload indicator
                    if viewModel.hasPendingUpload {
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
                    
                    // Data Source Indicator
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
                    
                    // Main Content
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error: error)
                    } else if viewModel.showResult, let result = viewModel.quizResult {
                        resultView(result: result)
                    } else if !viewModel.questions.isEmpty {
                        questionView
                    } else {
                        emptyStateView
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadQuiz()
            }
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
            
            if networkMonitor.isConnected {
                Button {
                    Task {
                        await viewModel.loadQuiz()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                VStack(spacing: 8) {
                    Text("Please connect to the internet and try again")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    Button {
                        Task {
                            await viewModel.loadQuiz()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        ScrollView {
            VStack(spacing: 24) {
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.progress)
                        .tint(Color("appRed"))
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Question card
                if let question = viewModel.currentQuestion {
                    VStack(alignment: .leading, spacing: 20) {
                        // Question image (if available)
                        if let imageUrl = question.imageUrl,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                                    .overlay(ProgressView())
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Question text
                        Text(question.text)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Options
                        VStack(spacing: 12) {
                            ForEach(question.options) { option in
                                Button {
                                    viewModel.selectAnswer(option)
                                } label: {
                                    HStack {
                                        Text(option.text)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Result View
    
    private func resultView(result: QuizResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Result card
                VStack(spacing: 20) {
                    // Emoji
                    Text(result.emoji)
                        .font(.system(size: 80))
                    
                    // Category
                    Text(result.moodCategory)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Tied indicator (if applicable)
                    if result.isTied {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("Mixed: \(result.tiedCategories.compactMap { QuizResult.categoryDisplayNames[$0] }.joined(separator: ", "))")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Description
                    Text(result.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Done button
                        Button {
                            Task {
                                await viewModel.handleDoneAction()
                                if !networkMonitor.isConnected {
                                    showOfflineSaveNotice = true
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(viewModel.isLoading ? "Saving..." : "Done")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("appRed"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isLoading)
                        
                        // Take Again button
                        Button {
                            Task {
                                await viewModel.handleTakeAgainAction()
                            }
                        } label: {
                            Text("Take Again")
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
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.top, 32)
            }
            .padding(.bottom, 32)
        }
        .alert("Saved Locally", isPresented: $showOfflineSaveNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're offline. Your result has been saved locally and will be uploaded when you reconnect.")
        }
    }
}

// MARK: - Preview

#Preview {
    MoodQuizView()
}
