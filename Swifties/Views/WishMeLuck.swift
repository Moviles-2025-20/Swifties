//
//  WishMeLuck.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//

import SwiftUI
import FirebaseFirestore

struct Magic8BallView: View {
    @State var events: [Event] = []
    @State private var selectedEvent: Event? = nil
    @State private var animateBall = false

    var body: some View {
        VStack {
            Spacer().frame(height: 40)

            // MARK: - Magic 8-Ball
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 280, height: 280)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 8)

                Text("8")
                    .font(.system(size: 130, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(animateBall ? 360 : 0))
                    .animation(.easeInOut(duration: 0.6), value: animateBall)
            }
            .padding(.top, 40)

            Spacer().frame(height: 30)

            // MARK: - Selected Event Info
            VStack(spacing: 12) {
                if let event = selectedEvent {

                    // Event Image
                    if !event.metadata.imageUrl.isEmpty {
                        AsyncImage(url: URL(string: event.metadata.imageUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(height: 120)
                        .cornerRadius(16)
                    } else {
                        Color.gray.opacity(0.3)
                            .frame(height: 120)
                            .cornerRadius(16)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }

                    // Event Name
                    Text(event.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    // Event Description
                    Text(event.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)

                    // Event Category and Type
                    HStack(spacing: 16) {
                        Label(event.category, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.orange)

                        Label(event.type, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    // Event Location, Duration, Cost
                    HStack(spacing: 16) {
                        Label(event.location?.address ?? "Address not found", systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Label("\(event.metadata.durationMinutes) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Label(formatCost(event.metadata.cost), systemImage: "dollarsign.circle")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    // Event Popularity and Rating
                    HStack(spacing: 16) {
                        Label("\(event.stats.popularity)% popular", systemImage: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)

                        Label(String(format: "%d ★", event.stats.rating), systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }

                } else {
                    Text("Shake or tap the button below")
                        .font(.body)
                        .foregroundColor(.primary)

                    Text("And let the magic 8-ball discover your perfect event!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 280)
            .padding(16)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
            .padding(.horizontal, 16)

            Spacer().frame(height: 20)

            // MARK: - Button
            Button(action: {
                if !events.isEmpty {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        animateBall.toggle()
                        selectedEvent = events.randomElement()
                    }
                }
            }) {
                Text("✨ Wish Me Luck!")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color("appPrimary").ignoresSafeArea())
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                loadEventsFromFirebase()
            }
        }
    }

    // MARK: - Helper to format cost
    private func formatCost(_ cost: EventCost) -> String {
        if cost.amount == 0 {
            return "Free"
        }
        return "\(cost.amount) \(cost.currency)"
    }

    // MARK: - Load events from Firebase
    func loadEventsFromFirebase() {
        let db = Firestore.firestore()
        db.collection("events").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }

            Task { @MainActor in
                self.events = docs.compactMap { doc -> Event? in
                    do {
                        return try doc.data(as: Event.self)
                    } catch {
                        print("Failed to decode Event from Firestore document \(doc.documentID): \(error)")
                        return nil
                    }
                }
            }
        }
    }
}

// MARK: - Preview with mock events
struct Magic8BallView_Previews: PreviewProvider {
    static var previews: some View {
        let mockEvents: [Event] = [
            Event(
                activetrue: true,
                category: "Music",
                created: "2025-10-05T18:00:00-05:00",
                description: "Live rock music concert",
                eventType: "Concert",
                location: EventLocation(
                    address: "Calle 123",
                    city: "Bogotá",
                    coordinates: [4.6097, -74.0817],
                    type: "Indoor"
                ),
                metadata: EventMetadata(
                    cost: EventCost(amount: 50000, currency: "COP"),
                    durationMinutes: 120,
                    imageUrl: "https://example.com/image.jpg",
                    tags: ["rock", "live", "music"]
                ),
                name: "Rock Fest",
                schedule: EventSchedule(
                    days: ["Friday", "Saturday"],
                    times: ["18:00", "20:00"]
                ),
                stats: EventStats(
                    popularity: 85,
                    rating: 4,
                    totalCompletions: 150
                ),
                title: "Rock Fest 2025",
                type: "Concert",
                weatherDependent: false
            ),
            Event(
                activetrue: true,
                category: "Art",
                created: "2025-10-05T10:00:00-05:00",
                description: "Modern art exhibition",
                eventType: "Exhibition",
                location: EventLocation(
                    address: "Carrera 7",
                    city: "Bogotá",
                    coordinates: [4.6533, -74.0836],
                    type: "Indoor"
                ),
                metadata: EventMetadata(
                    cost: EventCost(amount: 0, currency: "COP"),
                    durationMinutes: 90,
                    imageUrl: "https://example.com/art.jpg",
                    tags: ["art", "modern", "exhibition"]
                ),
                name: "Art Expo",
                schedule: EventSchedule(
                    days: ["Monday", "Tuesday"],
                    times: ["10:00", "14:00"]
                ),
                stats: EventStats(
                    popularity: 70,
                    rating: 5,
                    totalCompletions: 200
                ),
                title: "Art Expo 2025",
                type: "Exhibition",
                weatherDependent: false
            )
        ]
        return Magic8BallView(events: mockEvents)
    }
}
