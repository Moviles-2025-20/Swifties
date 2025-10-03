// RegisterView.swift
// Swifties
// Created by Natalia Villegas Calderón on 2/10/25.

import FirebaseAuth
import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject var viewModel = RegisterViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccessAlert = false
    @State private var navigateToHome = false
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name
        case email
    }
    
    let categories = ["Music", "Sport", "Academic", "Technology", "Movies", "Literature", "Know the world", "Food"]
    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    let majors = [
        "Ingenieria Industrial",
        "Ingenieria de Sistemas",
        "Economia",
        "Administracion"
    ]
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: Double(currentStep + 1), total: 5)
                    .tint(.appRed)
                    .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Step indicator
                        Text("Step \(currentStep + 1) of 5")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        // Current step content
                        Group {
                            switch currentStep {
                            case 0: basicInfoStep
                            case 1: genderBirthStep
                            case 2: preferencesStep
                            case 3: freeTimeSlotsStep
                            case 4: reviewStep
                            default: EmptyView()
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 100)
                }
            }
            
            // Navigation buttons
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: handleNext) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(currentStep == 4 ? "Save" : "Next")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appRed)
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Complete Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if currentStep > 0 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.appRed)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("Continue") {
                navigateToHome = true
            }
        } message: {
            Text("Your profile has been saved successfully!")
        }
        .fullScreenCover(isPresented: $navigateToHome) {
            HomeView()
                .environmentObject(authViewModel)
        }
        .onAppear {
            viewModel.initializeWithAuthUser(Auth.auth().currentUser)
        }
    }
    
    // MARK: - Step 1: Basic Info
    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Basic Information")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black.opacity(0.87))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                TextField("Enter your name", text: $viewModel.name)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .email
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                TextField("Enter your email", text: $viewModel.email)
                    .padding()
                    .background(viewModel.isEmailFromProvider ? Color.white.opacity(0.7) : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
                    .disabled(viewModel.isEmailFromProvider)
                
                if viewModel.isEmailFromProvider {
                    Text("Email from your login provider")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Major")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Menu {
                    ForEach(majors, id: \.self) { major in
                        Button(action: {
                            viewModel.major = major
                        }) {
                            HStack {
                                Text(major)
                                if viewModel.major == major {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.major.isEmpty ? "Select your major" : viewModel.major)
                            .foregroundColor(viewModel.major.isEmpty ? .gray : .black.opacity(0.87))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Step 2: Gender & Birth Date
    private var genderBirthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Personal Details")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black.opacity(0.87))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    ForEach(["Male", "Female", "Other"], id: \.self) { gender in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.gender = gender
                            }
                        }) {
                            Text(gender)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(viewModel.gender == gender ? .white : .black.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(viewModel.gender == gender ? Color.appRed : Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.gender == gender ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(height: 44)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Birth Date")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                DatePicker(
                    "Select birth date",
                    selection: $viewModel.birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Step 3: Preferences (WITH INDOOR/OUTDOOR SLIDER)
    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Preferences")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black.opacity(0.87))
            
            // Indoor/Outdoor Slider Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Do you usually prefer indoor or outdoor activities?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.87))
                
                VStack(spacing: 8) {
                    Slider(
                        value: $viewModel.indoorOutdoorScore,
                        in: 0...100,
                        step: 10
                    )
                    .tint(viewModel.indoorOutdoorScore <= 50 ? .blue : .green)
                    
                    HStack {
                        Text("Indoor")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(viewModel.indoorOutdoorScore <= 50 ? "Indoor" : "Outdoor")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(viewModel.indoorOutdoorScore <= 50 ? .blue : .green)
                        Spacer()
                        Text("Outdoor")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Categories Section
            Text("Select your favorite categories (at least one)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        viewModel.toggleCategory(category)
                    }) {
                        HStack {
                            Image(systemName: viewModel.favoriteCategories.contains(category) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.favoriteCategories.contains(category) ? .white : .gray)
                            
                            Text(category)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(viewModel.favoriteCategories.contains(category) ? .white : .black.opacity(0.7))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(viewModel.favoriteCategories.contains(category) ? Color.orange : Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.favoriteCategories.contains(category) ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Step 4: Free Time Slots
    private var freeTimeSlotsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Free Time Slots")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black.opacity(0.87))
            
            Text("Add at least one free time slot")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            VStack(spacing: 16) {
                Picker("Day", selection: $viewModel.selectedDay) {
                    Text("Select a day").tag(nil as String?)
                    ForEach(days, id: \.self) { day in
                        Text(day).tag(day as String?)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                HStack(spacing: 10) {
                    DatePicker("Start", selection: $viewModel.startTime, displayedComponents: .hourAndMinute)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: viewModel.startTime) { oldStart, newStart in
                            // Ensure end is always after start; bump end forward if needed
                            if viewModel.endTime <= newStart {
                                viewModel.endTime = Calendar.current.date(byAdding: .minute, value: 30, to: newStart)
                                    ?? Calendar.current.date(byAdding: .minute, value: 1, to: newStart)!
                            }
                        }
                    
                    DatePicker(
                        "End",
                        selection: $viewModel.endTime,
                        in: viewModel.startTime...endOfDay(for: viewModel.startTime),
                        displayedComponents: .hourAndMinute
                    )
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Button(action: {
                    // Validate end > start before adding
                    if viewModel.endTime <= viewModel.startTime {
                        alertMessage = "End time must be after the start time."
                        showAlert = true
                        return
                    }
                    viewModel.addFreeTimeSlot()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Time Slot")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appBlue)
                    .cornerRadius(12)
                }
            }
            
            if !viewModel.freeTimeSlots.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Added Slots")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.87))
                    
                    ForEach(Array(viewModel.freeTimeSlots.enumerated()), id: \.offset) { index, slot in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.appRed)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(slot["day"] ?? "")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(slot["start"] ?? "") - \(slot["end"] ?? "")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.removeFreeTimeSlot(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Step 5: Review
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Review Your Information")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black.opacity(0.87))
            
            VStack(spacing: 16) {
                reviewRow(title: "Name", value: viewModel.name)
                reviewRow(title: "Email", value: viewModel.email)
                reviewRow(title: "Major", value: viewModel.major)
                reviewRow(title: "Gender", value: viewModel.gender ?? "")
                reviewRow(title: "Age", value: "\(viewModel.calculateAge())")
                reviewRow(title: "Activity Preference", value: viewModel.indoorOutdoorScore <= 50 ? "Indoor (\(Int(viewModel.indoorOutdoorScore)))" : "Outdoor (\(Int(viewModel.indoorOutdoorScore)))")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(viewModel.favoriteCategories.joined(separator: ", "))
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.87))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Free Time Slots")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    ForEach(viewModel.freeTimeSlots, id: \.self) { slot in
                        Text("\(slot["day"] ?? ""): \(slot["start"] ?? "") - \(slot["end"] ?? "")")
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.87))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }
    
    private func reviewRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.87))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func handleNext() {
        switch currentStep {
        case 0:
            if viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty {
                alertMessage = "Please enter your name"
                showAlert = true
                return
            }
            if viewModel.email.trimmingCharacters(in: .whitespaces).isEmpty {
                alertMessage = "Please enter your email"
                showAlert = true
                return
            }
            if viewModel.major.trimmingCharacters(in: .whitespaces).isEmpty {
                alertMessage = "Please select your major"
                showAlert = true
                return
            }
        case 1:
            if viewModel.gender == nil {
                alertMessage = "Please select your gender"
                showAlert = true
                return
            }
        case 2:
            if viewModel.favoriteCategories.isEmpty {
                alertMessage = "Please select at least one category"
                showAlert = true
                return
            }
        case 3:
            if viewModel.freeTimeSlots.isEmpty {
                alertMessage = "Please add at least one free time slot"
                showAlert = true
                return
            }
        case 4:
            Task {
                do {
                    try await viewModel.saveUserData()
                    authViewModel.markAsReturningUser()
                    await MainActor.run {
                        showSuccessAlert = true
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to save profile: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
            return
        default:
            break
        }
        
        if currentStep < 4 {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    // Helper: end of day for given date (keeps selection within same day)
    private func endOfDay(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
}
