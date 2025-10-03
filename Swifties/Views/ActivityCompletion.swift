//
//  ActivityCompletion.swift
//  Swifties
//
//  Created by Imac  on 3/10/25.
//

import SwiftUI
import FirebaseFirestore
import Charts
import Combine

// MARK: - Activity Completion Model
struct ActivityCompletion: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var activityId: String
    var activityName: String
    var completedAt: Date
    var isWeeklyChallenge: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityId = "activity_id"
        case activityName = "activity_name"
        case completedAt = "completed_at"
        case isWeeklyChallenge = "is_weekly_challenge"
    }
}

// MARK: - Chart Data Model
struct DailyCompletion: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel
class WeeklyChallengeStatsViewModel: ObservableObject {
    @Published var completions: [ActivityCompletion] = []
    @Published var chartData: [DailyCompletion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalCompletions = 0
    @Published var averagePerWeek = 0.0
    
    private let db = Firestore.firestore()
    
    func loadCompletions(userId: String) {
        isLoading = true
        errorMessage = nil
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        db.collection("activity_completions")
            .whereField("user_id", isEqualTo: userId)
            .whereField("is_weekly_challenge", isEqualTo: true)
            .whereField("completed_at", isGreaterThanOrEqualTo: Timestamp(date: thirtyDaysAgo))
            .order(by: "completed_at", descending: false)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Error loading data: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.errorMessage = "No data found"
                        return
                    }
                    
                    self?.completions = documents.compactMap { doc in
                        try? doc.data(as: ActivityCompletion.self)
                    }
                    
                    self?.processChartData()
                }
            }
    }
    
    func processChartData() {
        let calendar = Calendar.current
        
        var dailyCounts: [Date: Int] = [:]
        
        for completion in completions {
            let dayStart = calendar.startOfDay(for: completion.completedAt)
            dailyCounts[dayStart, default: 0] += 1
        }
        
        var chartDataTemp: [DailyCompletion] = []
        for dayOffset in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                let dayStart = calendar.startOfDay(for: date)
                let count = dailyCounts[dayStart] ?? 0
                chartDataTemp.append(DailyCompletion(date: dayStart, count: count))
            }
        }
        
        chartData = chartDataTemp.reversed()
        totalCompletions = completions.count
        averagePerWeek = Double(totalCompletions) / 4.29
    }
}

// MARK: - Main View
struct WeeklyChallengeStatsView: View {
    @StateObject private var viewModel = WeeklyChallengeStatsViewModel()
    let userId: String
    
    var body: some View {
        ZStack {
            Color("appPrimary").ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomTopBar(title: "Challenge Stats", showNotificationButton: false) {
                    print("Back tapped")
                }
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading stats…")
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
                            viewModel.loadCompletions(userId: userId)
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Total",
                                    value: "\(viewModel.totalCompletions)",
                                    icon: "checkmark.circle.fill",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Per Week",
                                    value: String(format: "%.1f", viewModel.averagePerWeek),
                                    icon: "calendar",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Last 30 Days")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                
                                if viewModel.chartData.isEmpty {
                                    Text("No data to display")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 250)
                                } else {
                                    ChartView(data: viewModel.chartData)
                                        .frame(height: 250)
                                        .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Activities")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                
                                if viewModel.completions.isEmpty {
                                    Text("You haven't completed any weekly challenge activities")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(viewModel.completions.prefix(10)) { completion in
                                            CompletionRow(completion: completion)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            Spacer(minLength: 80)
                        }
                    }
                    .background(Color("appPrimary"))
                }
            }
        }
        .onAppear {
            viewModel.loadCompletions(userId: userId)
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Chart View Component
struct ChartView: View {
    let data: [DailyCompletion]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Day", item.date, unit: .day),
                y: .value("Completed", item.count)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 5)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Completion Row Component
struct CompletionRow: View {
    let completion: ActivityCompletion
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: completion.completedAt)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(completion.activityName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct WeeklyChallengeStatsView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyChallengeStatsView(userId: "preview_user_123")
    }
}
