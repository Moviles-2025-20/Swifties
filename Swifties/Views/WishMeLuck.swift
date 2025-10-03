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
                    if let imageUrl = event.metadata?.imageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
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

                        Label(event.type ?? "N/A", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    // Event Location, Duration, Cost
                    HStack(spacing: 16) {
                        Label(event.location?.address ?? "Unknown location", systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Label("\(event.metadata?.durationMinutes ?? 0) min", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Label(event.metadata?.cost ?? "N/A", systemImage: "dollarsign.circle")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    // Event Popularity and Rating
                    HStack(spacing: 16) {
                        Label("\(event.stats?.popularity ?? 0)% popular", systemImage: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)

                        Label(String(format: "%.1f ★", event.stats?.rating ?? 0), systemImage: "star.fill")
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

    // MARK: - Preview with mock events
    struct Magic8BallView_Previews: PreviewProvider {
        static var previews: some View {
            let mockEvents: [Event] = [
                Event(
                    id: "1",
                    title: "Rock Fest",
                    name: "Concert",
                    description: "Live music",
                    type: "Concert",
                    category: "Music",
                    active: true,
                    eventType: ["Music", "Concert"],
                    location: Event.Location(
                        city: "Bogotá",
                        type: "Indoor",
                        address: "Calle 123",
                        coordinates: [4.6097, -74.0817]
                    ),
                    schedule: Event.Schedule(
                        days: ["Friday", "Saturday"],
                        times: ["18:00", "20:00"]
                    ),
                    metadata: Event.Metadata(
                        imageUrl: "",
                        tags: ["rock", "live"],
                        durationMinutes: 120,
                        cost: "$50"
                    ),
                    stats: Event.EventStats(
                        popularity: 85,
                        totalCompletions: 150,
                        rating: 4.5
                    ),
                    weatherDependent: false,
                    created: Timestamp(date: Date())
                ),
                Event(
                    id: "2",
                    title: "Art Expo",
                    name: "Exhibition",
                    description: "Modern art",
                    type: "Exhibition",
                    category: "Art",
                    active: true,
                    eventType: ["Art", "Exhibition"],
                    location: Event.Location(
                        city: "Bogotá",
                        type: "Indoor",
                        address: "Carrera 7",
                        coordinates: [4.6533, -74.0836]
                    ),
                    schedule: Event.Schedule(
                        days: ["Monday", "Tuesday"],
                        times: ["10:00", "14:00"]
                    ),
                    metadata: Event.Metadata(
                        imageUrl: "",
                        tags: ["art", "modern"],
                        durationMinutes: 90,
                        cost: "Free"
                    ),
                    stats: Event.EventStats(
                        popularity: 70,
                        totalCompletions: 200,
                        rating: 4.8
                    ),
                    weatherDependent: false,
                    created: Timestamp(date: Date())
                )
            ]
            Magic8BallView(events: mockEvents)
        }
    }
}
