import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct WeeklyChallengeView: View {
    @StateObject private var viewModel = WeeklyChallengeViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom top bar with back button
                CustomTopBar(title: "Weekly Challenge",
                             showNotificationButton: true,
                             showBackButton: true,
                             onNotificationTap: {
                    print("Notification tapped")
                    
                },
                             onBackTap: {
                    dismiss()
                })
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading challenge...")
                        .foregroundColor(.primary)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("⚠️")
                            .font(.system(size: 50))
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Challenge Event Card
                            if let event = viewModel.challengeEvent {
                                VStack(spacing: 0) {
                                    // Event Image
                                    if let url = URL(string: event.metadata.imageUrl), !event.metadata.imageUrl.isEmpty {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Challenge Badge
                                        HStack {
                                            Image(systemName: "star.circle.fill")
                                                .foregroundColor(.yellow)
                                            Text("THIS WEEK'S CHALLENGE")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.orange)
                                            Spacer()
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
                                        
                                        // Event Details
                                        VStack(spacing: 8) {
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.orange)
                                                Text(event.schedule.days.joined(separator: ", "))
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text(event.schedule.times.first ?? "TBD")
                                                    .font(.subheadline)
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Image(systemName: "mappin.circle")
                                                    .foregroundColor(.red)
                                                Text(event.location?.address ?? "")
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        
                                        // Attend Button
                                        Button(action: {
                                            viewModel.markAsAttending()
                                        }) {
                                            HStack {
                                                Image(systemName: viewModel.hasAttended ? "checkmark.circle.fill" : "hand.raised.fill")
                                                Text(viewModel.hasAttended ? "Challenge Accepted!" : "I'm Going to Attend")
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(viewModel.hasAttended ? Color.green : Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                        .disabled(viewModel.hasAttended)
                                    }
                                    .padding()
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    Text("No challenge available this week")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                            
                            // Stats Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Progress")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                // Stats Grid
                                HStack(spacing: 12) {
                                    // Total Challenges
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "trophy.fill")
                                                .foregroundColor(.yellow)
                                                .font(.title2)
                                            Spacer()
                                        }
                                        Text("\(viewModel.totalChallenges)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.orange)
                                        Text("Total Challenges")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    
                                    // This Week
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                            Spacer()
                                        }
                                        Text("\(viewModel.hasAttended ? 1 : 0)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(viewModel.hasAttended ? .green : .blue)
                                        Text("This Week")
                                            .font(.caption)
                                            .foregroundColor(viewModel.hasAttended ? .green : .secondary)

                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                
                                // Last 4 Weeks Chart
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Weekly Challenge Streak")
                                            .font(.headline)
                                        Spacer()
                                        Text("Last 4 Weeks")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if viewModel.last30DaysData.isEmpty {
                                        VStack(spacing: 12) {
                                            Image(systemName: "chart.bar.xaxis")
                                                .font(.system(size: 40))
                                                .foregroundColor(.secondary.opacity(0.5))
                                            Text("No activity yet")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text("Complete your first weekly challenge!")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                    } else {
                                        VStack(spacing: 16) {
                                            // Weekly Challenge Indicators
                                            HStack(alignment: .center, spacing: 12) {
                                                ForEach(viewModel.last30DaysData) { data in
                                                    let isCompleted = data.count > 0
                                                    
                                                    VStack(spacing: 12) {
                                                        // Week Label on top
                                                        Text(data.label)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                            .multilineTextAlignment(.center)
                                                            .lineLimit(2)
                                                            .frame(height: 30)
                                                        
                                                        // Challenge Status Indicator
                                                        ZStack {
                                                            Circle()
                                                                .fill(isCompleted ?
                                                                      LinearGradient(
                                                                        colors: [Color.green, Color.green.opacity(0.7)],
                                                                        startPoint: .top,
                                                                        endPoint: .bottom
                                                                      ) :
                                                                      LinearGradient(
                                                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                                                        startPoint: .top,
                                                                        endPoint: .bottom
                                                                      )
                                                                )
                                                                .frame(width: 60, height: 60)
                                                            
                                                            if isCompleted {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.white)
                                                            } else {
                                                                Image(systemName: "xmark.circle")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.gray.opacity(0.5))
                                                            }
                                                        }
                                                        
                                                        // Status Text
                                                        Text(isCompleted ? "Completed" : "Missed")
                                                            .font(.caption2)
                                                            .fontWeight(isCompleted ? .semibold : .regular)
                                                            .foregroundColor(isCompleted ? .green : .secondary)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                            .padding(.vertical, 20)
                                            
                                            // Summary
                                            HStack(spacing: 20) {
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(Color.green)
                                                        .frame(width: 12, height: 12)
                                                    Text("Completed: \(viewModel.last30DaysData.filter { $0.count > 0 }.count)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 12, height: 12)
                                                    Text("Missed: \(viewModel.last30DaysData.filter { $0.count == 0 }.count)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.loadChallenge()
            }
        }
    }
}

extension Event: Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.name == rhs.name &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description
    }
}
