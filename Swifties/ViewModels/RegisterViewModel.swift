// RegisterViewModel.swift
// Swifties
// Created by Natalia Villegas Calderón on 2/10/25.

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class RegisterViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var major: String = ""
    @Published var gender: String? = nil
    @Published var birthDate: Date = Date()
    @Published var favoriteCategories: [String] = []
    @Published var freeTimeSlots: [[String: String]] = []
    @Published var isLoading: Bool = false
    @Published var indoorOutdoorScore: Double = 50
    
    // For UI state
    @Published var selectedDay: String? = nil
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date()
    
    // Track if email came from auth provider
    private var emailFromProvider: String? = nil
    private var isProviderEmail: Bool = false
    
    let db = Firestore.firestore(database: "default")
    private let syncService = RegistrationSyncService.shared
    private let networkMonitor = NetworkMonitorService.shared

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // ISO8601 formatter for consistent date serialization
    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    // MARK: - Computed Properties
    var isEmailFromProvider: Bool {
        return isProviderEmail
    }
    
    // MARK: - Initialization
    func initializeWithAuthUser(_ user: FirebaseAuth.User?) {
        if let user = user {
            name = user.displayName ?? ""
            
            if let userEmail = user.email, !userEmail.isEmpty {
                email = userEmail
                emailFromProvider = userEmail
                isProviderEmail = true
            } else {
                isProviderEmail = false
            }
            
            print("📧 Email initialized from provider: \(email)")
            print("🔒 Email from provider locked: \(isProviderEmail)")
        }
    }
    
    // MARK: - Category Management
    func toggleCategory(_ category: String) {
        if let index = favoriteCategories.firstIndex(of: category) {
            favoriteCategories.remove(at: index)
        } else {
            favoriteCategories.append(category)
        }
    }
    
    // MARK: - Free Time Slot Management
    func addFreeTimeSlot() {
        guard let day = selectedDay else { return }
        
        let startTimeString = dateFormatter.string(from: startTime)
        let endTimeString = dateFormatter.string(from: endTime)
        
        let slot: [String: String] = [
            "day": day,
            "start": startTimeString,
            "end": endTimeString
        ]
        
        freeTimeSlots.append(slot)
        selectedDay = nil
    }
    
    func removeFreeTimeSlot(at index: Int) {
        guard index >= 0 && index < freeTimeSlots.count else { return }
        freeTimeSlots.remove(at: index)
    }
    
    func updateFreeTimeSlot(at index: Int, start: String, end: String) {
        guard index >= 0 && index < freeTimeSlots.count else { return }
        freeTimeSlots[index]["start"] = start
        freeTimeSlots[index]["end"] = end
    }
    
    // MARK: - Age Calculation
    func calculateAge() -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year ?? 0
    }
    
    // MARK: - Step-by-Step Validation
    func validateCurrentStep(_ step: Int) -> (isValid: Bool, message: String) {
        switch step {
        case 0:
            return validateBasicInfo()
        case 1:
            return validatePersonalDetails()
        case 2:
            return validatePreferences()
        case 3:
            return validateFreeTimeSlots()
        case 4:
            return validateAllFields()
        default:
            return (true, "")
        }
    }
    
    // Step 0: Basic Info Validation
    private func validateBasicInfo() -> (isValid: Bool, message: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return (false, "Please enter your name (only blank spaces are not allowed)")
        }
        
        if containsEmoji(trimmedName) {
            return (false, "Name cannot contain emojis")
        }
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            return (false, "Please enter your email")
        }
        
        if !isValidEmail(trimmedEmail) {
            return (false, "Please enter a valid email address")
        }
        
        if major.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "Please select your major")
        }
        
        return (true, "")
    }
    
    // Step 1: Personal Details Validation
    private func validatePersonalDetails() -> (isValid: Bool, message: String) {
        if gender == nil {
            return (false, "Please select your gender")
        }
        
        let age = calculateAge()
        if age < 10 {
            return (false, "You must be at least 10 years old to register")
        }
        if age > 120 {
            return (false, "Please enter a valid birth date")
        }
        
        return (true, "")
    }
    
    // Step 2: Preferences Validation
    private func validatePreferences() -> (isValid: Bool, message: String) {
        if favoriteCategories.isEmpty {
            return (false, "Please select at least one category")
        }
        return (true, "")
    }
    
    // Step 3: Free Time Slots Validation
    private func validateFreeTimeSlots() -> (isValid: Bool, message: String) {
        if freeTimeSlots.isEmpty {
            return (false, "Please add at least one free time slot")
        }
        return (true, "")
    }
    
    // Step 4: Final Validation (all fields)
    private func validateAllFields() -> (isValid: Bool, message: String) {
        let basicValidation = validateBasicInfo()
        if !basicValidation.isValid {
            return basicValidation
        }
        
        let personalValidation = validatePersonalDetails()
        if !personalValidation.isValid {
            return personalValidation
        }
        
        let preferencesValidation = validatePreferences()
        if !preferencesValidation.isValid {
            return preferencesValidation
        }
        
        let slotsValidation = validateFreeTimeSlots()
        if !slotsValidation.isValid {
            return slotsValidation
        }
        
        return (true, "All fields are valid")
    }
    
    // MARK: - Helper: Email Validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Helper: Emoji Detection
    private func containsEmoji(_ string: String) -> Bool {
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x1F600...0x1F64F, 0x1F300...0x1F5FF, 0x1F680...0x1F6FF,
                 0x1F1E0...0x1F1FF, 0x2600...0x26FF, 0x2700...0x27BF,
                 0xFE00...0xFE0F, 0x1F900...0x1F9FF, 0x1F018...0x1F270,
                 0x238C...0x2454, 0x20D0...0x20FF:
                return true
            default:
                continue
            }
        }
        return false
    }
    
    // MARK: - Save to Firebase (THREE-LAYER STRATEGY - UPDATED)
    func saveUserData() async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ERROR: No authenticated user found")
            throw NSError(domain: "AuthError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
        }
        
        print("🔑 User ID: \(uid)")
        
        // Final validation before saving
        let validation = validateAllFields()
        if !validation.isValid {
            throw NSError(domain: "ValidationError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: validation.message])
        }
        
        print("✅ Validation passed")
        
        // Trim whitespace from name and email before saving
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get photo URL from current user
        let photoUrl = Auth.auth().currentUser?.photoURL?.absoluteString ?? ""
        let age = calculateAge()
        
        // Use ISO8601 date strings instead of FieldValue.serverTimestamp()
        let currentDateString = iso8601Formatter.string(from: Date())
        
        // Prepare data matching Flutter UserData model structure
        let userData: [String: Any] = [
            "profile": [
                "name": trimmedName,
                "email": trimmedEmail,
                "photo": photoUrl,
                "major": major,
                "gender": gender ?? "",
                "age": age,
                "created": currentDateString,
                "last_active": currentDateString
            ],
            "preferences": [
                "indoor_outdoor_score": Int(indoorOutdoorScore),
                "favorite_categories": favoriteCategories,
                "notifications": [
                    "free_time_slots": freeTimeSlots
                ]
            ]
        ]
        
        print("💾 Implementing THREE-LAYER persistence strategy...")
        
        // Use the sync service to handle three-layer strategy
        do {
            try await syncService.saveRegistrationData(userData)
            
            // CRITICAL: Mark registration as completed in UserDefaults
            // This ensures the app knows registration is done even if offline
            UserDefaultsService.shared.markRegistrationCompleted()
            
            print("✅ Registration data saved successfully!")
            
            // Log analytics only if connected
            if networkMonitor.isConnected {
                AnalyticsService.shared.setUserId(uid)
                AnalyticsService.shared.logOutdoorIndoorPreference(Int(indoorOutdoorScore))
            }
            
        } catch {
            print("❌ Error during save: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Reset
    func reset() {
        name = ""
        email = ""
        emailFromProvider = nil
        isProviderEmail = false
        major = ""
        gender = nil
        birthDate = Date()
        favoriteCategories = []
        freeTimeSlots = []
        selectedDay = nil
        startTime = Date()
        endTime = Date()
        indoorOutdoorScore = 50
    }
}
