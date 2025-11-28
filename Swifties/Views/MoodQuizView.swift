//
//  MoodQuizView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 27/11/25.
//
import SwiftUI
import Combine
import FirebaseAnalytics
import Network

struct MoodQuizView: View {
    @StateObject private var viewModel = MoodQuizViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showExitAlert = false
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.showResult {
                    resultView
                } else if !viewModel.questions.isEmpty {
                    quizContentView
                }
            }
            .navigationTitle("Mood Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showExitAlert = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Exit")
                        }
                        .foregroundColor(.appRed)
                    }
                }
            }
            .alert("Exit Quiz?", isPresented: $showExitAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Exit", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Your progress will be lost if you exit now.")
            }
            .alert("Success!", isPresented: $showSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your quiz result has been saved successfully!")
            }
            .alert("Error", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Failed to save result. Please try again.")
            }
        }
        .task {
            await viewModel.fetchQuestions()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appRed)
            Text("Loading quiz...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.system(size: 24, weight: .bold))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await viewModel.fetchQuestions()
                }
            }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Quiz Content View
    private var quizContentView: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: viewModel.progress)
                .tint(.appRed)
                .padding()
            
            // Question counter
            Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.questions.count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 24) {
                    if let question = viewModel.currentQuestion {
                        questionCard(question)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
    }
    
    // MARK: - Question Card
    private func questionCard(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Question text
            Text(question.text)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black.opacity(0.87))
                .fixedSize(horizontal: false, vertical: true)
            
            // Optional image
            if let imageUrl = question.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Options
            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    optionButton(option)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Option Button
    private func optionButton(_ option: QuizOption) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectAnswer(option: option)
            }
        }) {
            HStack {
                Text(option.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.isOptionSelected(option.text) ? .white : .black.opacity(0.87))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if viewModel.isOptionSelected(option.text) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(viewModel.isOptionSelected(option.text) ? Color.appRed : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isOptionSelected(option.text) ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        VStack {
            HStack(spacing: 16) {
                if viewModel.currentQuestionIndex > 0 {
                    Button(action: {
                        withAnimation {
                            viewModel.goToPreviousQuestion()
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appRed, lineWidth: 2)
                        )
                    }
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.goToNextQuestion()
                    }
                }) {
                    HStack {
                        Text(viewModel.isLastQuestion ? "Finish" : "Next")
                        if !viewModel.isLastQuestion {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.canGoNext ? Color.appRed : Color.gray.opacity(0.5))
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canGoNext)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Result View
    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let result = viewModel.quizResult {
                // Emoji
                Text(result.emoji)
                    .font(.system(size: 100))
                    .padding(.bottom, 16)
                
                // Category title - with dynamic sizing
                Text(result.moodCategory)
                    .font(.system(size: dynamicTitleSize(for: result.moodCategory), weight: .bold))
                    .foregroundColor(.black.opacity(0.87))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                
                // Description
                Text(result.description)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                
                // Score
                Text("Total Score: \(result.totalScore)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appRed)
                    .padding(.top, 8)
                
                // Tie indicator
                if result.isTied {
                    HStack(spacing: 8) {
                        Image(systemName: "equal.circle.fill")
                            .foregroundColor(.orange)
                        Text(result.tiedCategories.count == 2 ? "Mixed Result" : "Multiple Affinities")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.top, 8)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await viewModel.saveResultToFirebase()
                        if viewModel.errorMessage == nil {
                            showSaveSuccess = true
                        } else {
                            showSaveError = true
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Result")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appRed)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
                
                Button(action: {
                    withAnimation {
                        viewModel.resetQuiz()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retake Quiz")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appRed, lineWidth: 2)
                    )
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Sizing helper function
private func dynamicTitleSize(for text: String) -> CGFloat {
    if text.count > 25 {
        return 22
    } else if text.count > 20 {
        return 26
    } else {
        return 32
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            MoodQuizView()
        }
}
