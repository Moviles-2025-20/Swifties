// AddCommentView.swift
// New screen to compose a comment with title, description (500-word limit), rating, emotion, and photo attach.

import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth

struct AddCommentView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    private let commentViewModel = CommentViewModel()

    // Inputs
    @State private var reviewTitle: String = ""
    @State private var reviewDescription: String = ""
    @State private var rating: Int = 0
    @State private var selectedEmotion: Emotion = .happy

    // Photos
    @State private var selectedImage: UIImage? = nil
    @State private var showCameraPicker: Bool = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    @State private var showCameraUnavailableAlert: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var submitError: String? = nil

    // Word limit
    private let wordLimit: Int = 500

    var body: some View {
        ZStack(alignment: .top) {
            Color("appPrimary")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CustomTopBar(
                    title: "Leave a Comment",
                    showNotificationButton: false,
                    showBackButton: true,
                    onNotificationTap: {},
                    onBackTap: { dismiss() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                            TextField("Add a title to your review", text: $reviewTitle)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.sentences)
                        }

                        // Description with word limit
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $reviewDescription)
                                    .frame(minHeight: 140)
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .onChange(of: reviewDescription) { _ in
                                        if commentViewModel.currentWordCount(reviewDescription: reviewDescription) > wordLimit {
                                            reviewDescription = commentViewModel.enforceWordLimit(reviewDescription: reviewDescription, wordLimit: wordLimit)
                                        }
                                    }

                                // Placeholder
                                if reviewDescription.isEmpty {
                                    Text("Share your experience (max \(wordLimit) words)...")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                }
                            }
                            HStack {
                                Spacer()
                                Text("\(commentViewModel.currentWordCount(reviewDescription: reviewDescription))/\(wordLimit) words")
                                    .font(.caption)
                                    .foregroundColor(commentViewModel.currentWordCount(reviewDescription: reviewDescription) > wordLimit ? .red : .secondary)
                            }
                        }

                        // Rating stars
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating")
                                .font(.headline)
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { index in
                                    Button(action: { rating = index }) {
                                        Image(systemName: index <= rating ? "star.fill" : "star")
                                            .foregroundColor(index <= rating ? .yellow : .gray)
                                            .font(.system(size: 28))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Emotion picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How did it make you feel?")
                                .font(.headline)
                            Picker("Emotion", selection: $selectedEmotion) {
                                ForEach(Emotion.allCases) { emotion in
                                    Text("\(emotion.emoji) - \(emotion.title)")
                                        .tag(emotion)
                                        .font(.caption)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Photo attach
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a photo")
                                .font(.headline)

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(12)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        showCameraPicker = true
                                    } else {
                                        showCameraUnavailableAlert = true
                                    }
                                } label: {
                                    Label("Take Photo", systemImage: "camera")
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(10)
                                }

                                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(10)
                                }
                                .onChange(of: photoPickerItem) { _ in
                                    Task { await loadImageFromPhotosPicker() }
                                }
                            }
                        }

                        // Submit button
                        Button {
                            guard !isSubmitting else { return }
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                }
                                Text("Submit Review")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSubmitDisabled || isSubmitting ? Color.gray : Color("appBlue"))
                            .cornerRadius(12)
                        }
                        .disabled(isSubmitDisabled || isSubmitting)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera, image: $selectedImage)
                .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not support the camera.")
        }
        .alert("Failed to Submit", isPresented: .constant(submitError != nil), presenting: submitError) { _ in
            Button("OK", role: .cancel) { submitError = nil }
        } message: { errorMessage in
            Text(errorMessage)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var isSubmitDisabled: Bool {
        reviewTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        reviewDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        rating == 0 ||
        commentViewModel.currentWordCount(reviewDescription: reviewDescription) > wordLimit
    }

    @MainActor
    private func submit() async {
        // Validate prerequisites
        guard let eventId = event.id, !eventId.isEmpty else {
            submitError = "Missing event identifier."
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            submitError = "You must be logged in to submit a comment."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let payload = CommentViewModel.SubmissionPayload(
            eventId: eventId,
            userId: uid,
            title: reviewTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            text: reviewDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            image: selectedImage,
            rating: rating,
            emotion: selectedEmotion.title
        )

        do {
            try await commentViewModel.submit(payload)
            dismiss()
        } catch {
            submitError = (error as NSError).localizedDescription
        }
    }
    
    // MARK: Loading images helper
    func loadImageFromPhotosPicker() async {
        guard let item: PhotosPickerItem = photoPickerItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        } catch {
            print("Failed to load image from photo picker:", error)
            await MainActor.run {
                submitError = "Failed to load image. \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Emotion

enum Emotion: String, CaseIterable, Identifiable {
    case sad, happy, angry, emotional
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .sad: return "😢"
        case .happy: return "🥳"
        case .angry: return "😡"
        case .emotional: return "🥹"
        }
    }
}

