
//
//  WishMeLuck.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//

import Foundation
import SwiftUI
import CoreMotion

struct WishMeLuckView: View {
    @StateObject private var viewModel = WishMeLuckViewModel()
    @State private var animateBall = false
    @State private var isShaking = false
    
    // Accelerometer
    private let motionManager = CMMotionManager()
    @State private var lastShakeTime: Date?
    private let shakeThreshold: Double = 2.5
    private let shakeCooldown: TimeInterval = 3.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appPrimary")
                    .ignoresSafeArea()
                
                VStack {
                    CustomTopBar(
                        title: "Wish Me Luck",
                        showNotificationButton: true,
                        onBackTap: {}
                    )
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // MARK: - Header Section
                            HeaderSection(daysSinceLastWished: viewModel.daysSinceLastWished)
                                .padding(.horizontal, 20)
                            
                            // MARK: - Magic 8-Ball
                            Magic8BallCard(
                                isLoading: viewModel.isLoading,
                                animateBall: $animateBall
                            )
                            .padding(.horizontal, 20)
                            
                            // MARK: - Motivational Message
                            if let _ = viewModel.currentEvent {
                                MotivationalMessageCard(message: viewModel.getMotivationalMessage())
                                    .padding(.horizontal, 20)
                            }
                            
                            // MARK: - Event Preview or Empty State
                            if let event = viewModel.currentEvent {
                                EventPreviewCard(event: event)
                                    .padding(.horizontal, 20)
                            } else if !viewModel.isLoading {
                                EmptyStateCard()
                                    .padding(.horizontal, 20)
                            }
                            
                            // MARK: - Wish Me Luck Button
                            WishMeLuckButton(isLoading: viewModel.isLoading) {
                                Task {
                                    await triggerWish()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.calculateDaysSinceLastWished()
                startAccelerometerUpdates()
            }
            .onDisappear {
                stopAccelerometerUpdates()
            }
        }
    }
    
    // MARK: - Trigger Wish
    private func triggerWish() async {
        withAnimation(.easeInOut(duration: 0.5)) {
            animateBall = true
        }
        
        await viewModel.wishMeLuck()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                animateBall = false
            }
        }
    }
    
    // MARK: - Accelerometer
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            guard let data = data, error == nil else { return }
            
            let acceleration = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            
            if acceleration > shakeThreshold {
                handleShake()
            }
        }
    }
    
    private func stopAccelerometerUpdates() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func handleShake() {
        let now = Date()
        
        // Check cooldown
        if let lastShake = lastShakeTime,
           now.timeIntervalSince(lastShake) < shakeCooldown {
            return
        }
        
        // Don't shake if already loading
        guard !viewModel.isLoading else { return }
        
        lastShakeTime = now
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            await triggerWish()
        }
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    let daysSinceLastWished: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Days since last wished")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(daysSinceLastWished)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Color("appBlue"))
            
            Text(daysSinceLastWished == 1 ? "day" : "days")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Magic 8-Ball Card
struct Magic8BallCard: View {
    let isLoading: Bool
    @Binding var animateBall: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Shake your phone or tap the button")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 8)
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    Text("8")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(animateBall ? 360 : 0))
                        .animation(.easeInOut(duration: 0.6), value: animateBall)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Motivational Message Card
struct MotivationalMessageCard: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundColor(Color("appOcher"))
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Event Preview Card
struct EventPreviewCard: View {
    let event: WishMeLuckEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event Image
            if !event.imageUrl.isEmpty {
                AsyncImage(url: URL(string: event.imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            
            // Event Title
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Event Description
            Text(event.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.sparkles.inverse")
                .font(.system(size: 50))
                .foregroundColor(Color("appBlue").opacity(0.6))
            
            Text("Shake or tap the button below")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("And let the magic 8-ball discover your perfect event!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Wish Me Luck Button
struct WishMeLuckButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                
                Text(isLoading ? "Finding your event..." : "✨ Wish Me Luck!")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLoading ? Color.gray : Color.orange)
            .cornerRadius(16)
        }
        .disabled(isLoading)
    }
}

// MARK: - Preview
struct WishMeLuckView_Previews: PreviewProvider {
    static var previews: some View {
        WishMeLuckView()
    }
}
