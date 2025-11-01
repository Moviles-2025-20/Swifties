//
//  UserDefaultsService.swift
//  Swifties
//
//  Three-layer persistence: Firebase Cache -> UserDefaults -> Firestore
//

import Foundation

class UserDefaultsService {
    static let shared = UserDefaultsService()
    
    private let defaults = UserDefaults.standard
    
    // Keys for storing registration data
    private enum Keys {
        static let registrationData = "pending_registration_data"
        static let hasPendingRegistration = "has_pending_registration"
        static let lastSaveAttempt = "last_save_attempt"
    }
    
    private init() {}
    
    // MARK: - Save Registration Data Locally
    func saveRegistrationData(_ data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            defaults.set(jsonData, forKey: Keys.registrationData)
            defaults.set(true, forKey: Keys.hasPendingRegistration)
            defaults.set(Date(), forKey: Keys.lastSaveAttempt)
            defaults.synchronize() // Force immediate save (though not strictly necessary)
            print("✅ Registration data saved to UserDefaults")
        } catch {
            print("❌ Failed to save registration data to UserDefaults: \(error)")
        }
    }
    
    // MARK: - Get Pending Registration Data
    func getPendingRegistrationData() -> [String: Any]? {
        guard hasPendingRegistration() else { return nil }
        
        guard let jsonData = defaults.data(forKey: Keys.registrationData) else {
            print("⚠️ No registration data found in UserDefaults")
            return nil
        }
        
        do {
            let data = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            print("✅ Retrieved registration data from UserDefaults")
            return data
        } catch {
            print("❌ Failed to retrieve registration data from UserDefaults: \(error)")
            return nil
        }
    }
    
    // MARK: - Check if there's pending registration
    func hasPendingRegistration() -> Bool {
        return defaults.bool(forKey: Keys.hasPendingRegistration)
    }
    
    // MARK: - Clear Registration Data (after successful upload)
    func clearRegistrationData() {
        defaults.removeObject(forKey: Keys.registrationData)
        defaults.set(false, forKey: Keys.hasPendingRegistration)
        defaults.removeObject(forKey: Keys.lastSaveAttempt)
        print("✅ Cleared registration data from UserDefaults")
    }
    
    // MARK: - Get Last Save Attempt
    func getLastSaveAttempt() -> Date? {
        return defaults.object(forKey: Keys.lastSaveAttempt) as? Date
    }
}