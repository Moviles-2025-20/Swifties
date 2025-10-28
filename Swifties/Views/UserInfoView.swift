//
//  UserInfoView.swift
//  Swifties
//
//  Created by
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserInfoView: View {
    @StateObject private var viewModel = UserInfoViewModel()
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Computed Properties for Data Source
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
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomTopBar(title: "Available Events",
                             showNotificationButton: true,
                             showBackButton: true,
                             onNotificationTap: {
                    print("Notification tapped")
                },
                             onBackTap: {
                    dismiss()
                })
                
                // Data Source Indicator
                if !viewModel.isLoading && !viewModel.availableEvents.isEmpty {
                    HStack {
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
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading your available events...")
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
                        Button("Retry") {
                            viewModel.loadData()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Free Time Slots Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Free Time")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                if viewModel.freeTimeSlots.isEmpty {
                                    Text("No free time slots configured")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.freeTimeSlots) { slot in
                                            HStack {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.orange)
                                                Text(slot.day)
                                                    .fontWeight(.semibold)
                                                Spacer()
                                                Image(systemName: "clock")
                                                    .foregroundColor(.blue)
                                                Text("\(slot.start) - \(slot.end)")
                                                    .font(.subheadline)
                                            }
                                            .padding()
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            // Available Events Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Events That Fit Your Schedule")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("\(viewModel.availableEvents.count)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal)
                                
                                if viewModel.availableEvents.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                        Text("No events match your free time")
                                            .foregroundColor(.secondary)
                                        Text("Try adjusting your availability or check back later")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(viewModel.availableEvents, id: \.title) { event in
                                            NavigationLink(destination: EventDetailView(event: event)) {
                                                EventInfo(
                                                    imagePath: event.metadata.imageUrl,
                                                    title: event.name,
                                                    titleColor: Color.green,
                                                    description: event.description,
                                                    timeText: formatEventTime(event: event),
                                                    walkingMinutes: 5,
                                                    location: event.location?.address
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                        .padding(.top, 16)
                    }
                }
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                viewModel.debugCache()
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Helper formatter function for including date
private func formatEventTime(event: Event) -> String {
    let day = event.schedule.days.first ?? ""
    let time = event.schedule.times.first ?? "Time TBD"
    
    if day.isEmpty {
        return time
    } else {
        return "\(day), \(time)"
    }
}

// MARK: - Preview
struct UserInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UserInfoView()
        }
    }
}
