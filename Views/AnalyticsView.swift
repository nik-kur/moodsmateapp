import SwiftUI
import Charts
import FirebaseAuth

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
}

struct AnalyticsView: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedInsightIndex: Int? = nil
    @State private var selectedBarIndex: Int? = nil
    @State private var dataRefreshTrigger = false
    @StateObject private var networkMonitor = NetworkMonitor()

    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255),
        gradient: [
            Color(red: 147/255, green: 112/255, blue: 219/255),
            Color(red: 126/255, green: 188/255, blue: 237/255)
        ],
        moodColors: [
            Color(red: 169/255, green: 169/255, blue: 169/255),  // Depressed
            Color(red: 176/255, green: 196/255, blue: 222/255),  // Down
            Color(red: 135/255, green: 206/255, blue: 235/255),  // Neutral
            Color(red: 98/255, green: 182/255, blue: 183/255),   // Good
            Color(red: 255/255, green: 215/255, blue: 0/255)     // Euphoric
        ]
    )


    var body: some View {
        if !networkMonitor.isConnected {
            OfflineView()
        } else if viewModel.moodEntries.isEmpty {
            NoDataView()
                .onAppear {
                                print("AnalyticsView is loading...")
                                print("Mood Entries Count: \(viewModel.moodEntries.count)")
                                
                                if let firstEntry = viewModel.moodEntries.first {
                                    print("First Mood Entry - Date: \(firstEntry.date), Mood: \(firstEntry.moodLevel)")
                                } else {
                                    print("No mood entries found.")
                                }
                            }
        } else {
            ZStack {
                
                colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Analytics")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Understand your patterns")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                Spacer()

                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, getSafeAreaTop())
                        .padding(.bottom, 24)
                        .background(
                            colors.secondary
                                .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                        )

                        VStack(spacing: 30) {
                            // Mood Summary Card
                            MoodSummaryCard(viewModel: viewModel, colors: colors)
                                .id(dataRefreshTrigger)
                                .padding(.horizontal)
                                .padding(.top, 24)

                            // Key Insights Section
                            EnhancedInsightsSection(
                                viewModel: viewModel,
                                colors: colors,
                                selectedIndex: $selectedInsightIndex
                            )
                            .padding(.horizontal)

                            // Mood Trend Chart with Time Range Selector
                            MoodTrendSection(
                                viewModel: viewModel,
                                selectedTimeRange: $selectedTimeRange,
                                colors: colors
                            )
                            .id(dataRefreshTrigger)
                            .padding(.horizontal)

                            // Factor Impact Analysis
                            FactorImpactSection(viewModel: viewModel, colors: colors)
                                .id(dataRefreshTrigger)
                                .padding(.horizontal)

                            .padding(.bottom, 90)
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .onReceive(viewModel.$moodEntries) { _ in
                print("Mood entries updated, forcing full UI refresh")
                DispatchQueue.main.async {
                    self.dataRefreshTrigger.toggle() // 🔹 This forces a full SwiftUI re-render
                }
            }




            .onAppear {
                print("AnalyticsView showing data. Entry count: \(viewModel.moodEntries.count)")
                if let firstEntry = viewModel.moodEntries.first {
                    print("First entry date: \(firstEntry.date), mood: \(firstEntry.moodLevel)")
                }

                // ✅ Explicitly refresh analytics data when the view appears
                DispatchQueue.main.async {
                    viewModel.fetchMoodEntries() // 🔹 Ensure fresh data is always loaded
                }
            }

        }
    }

    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}


// MARK: - Mood Summary Card
struct MoodSummaryCard: View {
    let viewModel: MoodTrackerViewModel
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    
    var weeklyAverage: Double {
        let weekData = viewModel.getMoodTrendData(for: .week)
        guard !weekData.isEmpty else { return 0 }
        return weekData.map { $0.moodLevel }.reduce(0, +) / Double(weekData.count)
    }
    
    var weeklyMoodDescription: String {
        switch weeklyAverage {
        case 8...10: return "Euphoric"
        case 6...8: return "Good"
        case 4...6: return "Neutral"
        case 2...4: return "Down"
        case 0...2: return "Depressed"
        default: return "Unknown"
        }
    }
    
    var weeklyMoodIcon: String {
        switch weeklyAverage {
        case 8...10: return "sun.max.fill"
        case 6...8: return "sun.and.horizon.fill"
        case 4...6: return "cloud.sun.fill"
        case 2...4: return "cloud.fill"
        case 0...2: return "cloud.rain.fill"
        default: return "questionmark"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Weekly Average")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(colors.secondary)
                    
                    Text("Your past 7 days")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(getMoodColor(weeklyAverage).opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: weeklyMoodIcon)
                        .font(.system(size: 30))
                        .foregroundColor(getMoodColor(weeklyAverage))
                }
            }
            
            Divider()
                .padding(.horizontal, 10)
            
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(String(format: "%.1f", weeklyAverage))")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(getMoodColor(weeklyAverage))
                    
                    Text(weeklyMoodDescription)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(getMoodColor(weeklyAverage))
                        
                    Text("Average for the last 7 days")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Week day visualization with mood icons
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(getWeekdayLabels(), id: \.self) { day in
                            Text(day)
                                .font(.system(size: 11))
                                .frame(width: 24)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        ForEach(getLastSevenDaysMoods(), id: \.date) { entry in
                            ZStack {
                                Circle()
                                    .fill(getMoodColor(entry.moodLevel).opacity(entry.moodLevel > 0 ? 0.15 : 0.05))
                                    .frame(width: 24, height: 24)
                                
                                if entry.moodLevel > 0 {
                                    Image(systemName: getDayIcon(for: entry.moodLevel))
                                        .font(.system(size: 12))
                                        .foregroundColor(getMoodColor(entry.moodLevel))
                                } else {
                                    Circle()
                                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                        .frame(width: 18, height: 18)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func getWeekdayLabels() -> [String] {
        let calendar = Calendar.current
        let today = Date()
        var weekdayLabels: [String] = []
        
        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let formatter = DateFormatter()
                formatter.dateFormat = "E"
                let dayLabel = formatter.string(from: date).prefix(1)
                weekdayLabels.append(String(dayLabel))
            }
        }
        
        return weekdayLabels
    }
    
    private func getLastSevenDaysMoods() -> [MoodTrendEntry] {
        let calendar = Calendar.current
        let today = Date()
        var result: [MoodTrendEntry] = []
        
        for dayOffset in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                if let entry = viewModel.getEntry(for: date) {
                    result.append(MoodTrendEntry(date: date, moodLevel: entry.moodLevel))
                } else {
                    result.append(MoodTrendEntry(date: date, moodLevel: 0))
                }
            }
        }
        
        return result
    }
    
    private func getDayIcon(for moodLevel: Double) -> String {
        switch moodLevel {
        case 8...10: return "sun.max.fill"
        case 6...8: return "sun.and.horizon.fill"
        case 4...6: return "cloud.sun.fill"
        case 2...4: return "cloud.fill"
        case 0...2: return "cloud.rain.fill"
        default: return "circle"
        }
    }
    
    private func getMoodColor(_ level: Double) -> Color {
        switch level {
        case 8...10: return colors.moodColors[4]
        case 6...8: return colors.moodColors[3]
        case 4...6: return colors.moodColors[2]
        case 2...4: return colors.moodColors[1]
        case 0...2: return colors.moodColors[0]
        default: return Color.gray
        }
    }
}

// MARK: - Enhanced Insights Section
struct EnhancedInsightsSection: View {
    let viewModel: MoodTrackerViewModel
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    @Binding var selectedIndex: Int?
    
    var enhancedInsights: [InsightItem] {
        var insights: [InsightItem] = []
        
        // 1. Weekly average insight
        let weekData = viewModel.getMoodTrendData(for: .week)
        if !weekData.isEmpty {
            let average = weekData.map { $0.moodLevel }.reduce(0, +) / Double(weekData.count)
            let trend = getWeeklyTrend()
            
            var description = "Your average mood for the past week is \(String(format: "%.1f", average))"
            if let trendValue = trend {
                description += trendValue > 0
                    ? " (↑ \(String(format: "%.1f", trendValue)) from previous week)"
                    : " (↓ \(String(format: "%.1f", abs(trendValue))) from previous week)"
            }
            
            insights.append(InsightItem(
                title: "Weekly Mood Average",
                description: description,
                icon: "chart.bar.fill",
                color: getMoodColor(average)
            ))
        }
        
        // 2. Most impactful positive factors with reason
        let topPositiveFactors = getTopFactors().positive
        if !topPositiveFactors.isEmpty {
            let factorsList = topPositiveFactors.map { "\($0.name) (\($0.count) times)" }.joined(separator: ", ")
            insights.append(InsightItem(
                title: "Top Positive Factors",
                description: "These had the most positive impact on your mood this week: \(factorsList)",
                icon: "arrow.up.heart.fill",
                color: colors.positive
            ))
        }

        // 3. Most impactful negative factors with reason
        let topNegativeFactors = getTopFactors().negative
        if !topNegativeFactors.isEmpty {
            let factorsList = topNegativeFactors.map { "\($0.name) (\($0.count) times)" }.joined(separator: ", ")
            insights.append(InsightItem(
                title: "Top Negative Factors",
                description: "These negatively affected your mood the most this week: \(factorsList)",
                icon: "arrow.down.heart.fill",
                color: colors.negative
            ))
        }

        
        // 4. Consistency insight
        let consistency = getConsistencyMetric()
        if consistency > 0 {
            let consistencyDesc = consistency > 0.7
                ? "Your mood has been very stable"
                : (consistency > 0.4 ? "Your mood has been moderately stable" : "Your mood has fluctuated significantly")
            
            insights.append(InsightItem(
                title: "Mood Stability",
                description: "\(consistencyDesc) over the past week",
                icon: consistency > 0.5 ? "waveform.path.ecg" : "waveform",
                color: consistency > 0.5 ? colors.positive : colors.secondary
            ))
        }
        
        return insights
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(colors.secondary)
            
            VStack(spacing: 12) {
                ForEach(Array(enhancedInsights.enumerated()), id: \.element.id) { index, insight in
                    InsightCard(
                        insight: insight,
                        isSelected: selectedIndex == index,
                        colors: colors
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedIndex == index {
                                selectedIndex = nil
                            } else {
                                selectedIndex = index
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getWeeklyTrend() -> Double? {
        let calendar = Calendar.current
        let today = Date()
        

        
        let entries = viewModel.moodEntries.filter { entry in
            calendar.dateComponents([.day], from: entry.date, to: today).day ?? 15 <= 14
        }
        
        let currentWeekEntries = entries.filter { entry in
            calendar.dateComponents([.day], from: entry.date, to: today).day ?? 15 <= 7
        }
        
        let previousWeekEntries = entries.filter { entry in
            let days = calendar.dateComponents([.day], from: entry.date, to: today).day ?? 0
            return days > 7 && days <= 14
        }
        
        guard !currentWeekEntries.isEmpty, !previousWeekEntries.isEmpty else {
            return nil
        }
        
        let currentAvg = currentWeekEntries.map { $0.moodLevel }.reduce(0, +) / Double(currentWeekEntries.count)
        let previousAvg = previousWeekEntries.map { $0.moodLevel }.reduce(0, +) / Double(previousWeekEntries.count)
        
        return currentAvg - previousAvg
    }
    
    private func getTopFactors() -> (positive: [(name: String, count: Int)], negative: [(name: String, count: Int)]) {
        let calendar = Calendar.current
        let today = Date()

        let weekEntries = viewModel.moodEntries.filter { entry in
            calendar.dateComponents([.day], from: entry.date, to: today).day ?? 8 <= 7
        }

        var factorCounts: [String: (positive: Int, negative: Int)] = [:]

        for entry in weekEntries {
            for (factor, impact) in entry.factors {
                if factorCounts[factor] == nil {
                    factorCounts[factor] = (positive: 0, negative: 0)
                }
                if impact == .positive {
                    factorCounts[factor]!.positive += 1
                } else {
                    factorCounts[factor]!.negative += 1
                }
            }
        }

        let maxPositiveCount = factorCounts.values.map { $0.positive }.max() ?? 0
        let maxNegativeCount = factorCounts.values.map { $0.negative }.max() ?? 0

        let topPositiveFactors = factorCounts
            .filter { $0.value.positive == maxPositiveCount && maxPositiveCount > 0 }
            .map { (name: $0.key, count: $0.value.positive) }

        let topNegativeFactors = factorCounts
            .filter { $0.value.negative == maxNegativeCount && maxNegativeCount > 0 }
            .map { (name: $0.key, count: $0.value.negative) }

        return (topPositiveFactors, topNegativeFactors)
    }

    
    private func getConsistencyMetric() -> Double {
        let weekData = viewModel.getMoodTrendData(for: .week)
        guard weekData.count > 1 else { return 0 }
        
        let moodLevels = weekData.map { $0.moodLevel }
        let average = moodLevels.reduce(0, +) / Double(moodLevels.count)
        
        // Calculate standard deviation
        let sumOfSquaredDifferences = moodLevels.reduce(0) { sum, mood in
            let difference = mood - average
            return sum + (difference * difference)
        }
        
        let standardDeviation = sqrt(sumOfSquaredDifferences / Double(moodLevels.count))
        
        // Convert to a 0-1 scale where 1 is very consistent (low standard deviation)
        // and 0 is very inconsistent (high standard deviation)
        return max(0, min(1, 1 - (standardDeviation / 3)))
    }
    
    private func getMoodColor(_ level: Double) -> Color {
        switch level {
        case 8...10: return colors.moodColors[4]
        case 6...8: return colors.moodColors[3]
        case 4...6: return colors.moodColors[2]
        case 2...4: return colors.moodColors[1]
        case 0...2: return colors.moodColors[0]
        default: return Color.gray
        }
    }
}

struct InsightItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct InsightCard: View {
    let insight: InsightItem
    let isSelected: Bool
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSelected ? 16 : 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(insight.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: insight.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(insight.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if !isSelected {
                        Text(insight.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.secondary.opacity(0.5))
            }
            
            if isSelected {
                Text(insight.description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 52)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Mood Trend Section
struct MoodTrendSection: View {
    let viewModel: MoodTrackerViewModel
    @Binding var selectedTimeRange: TimeRange
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Mood Trend")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colors.secondary)
                
                Spacer()
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            
            VStack(spacing: 16) {
                Text("Your mood patterns over time")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Chart {
                    ForEach(viewModel.getMoodTrendData(for: selectedTimeRange)) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Mood", entry.moodLevel)
                        )
                        .foregroundStyle(colors.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("Mood", entry.moodLevel)
                        )
                        .foregroundStyle(colors.secondary.opacity(0.2))
                        
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Mood", entry.moodLevel)
                        )
                        .foregroundStyle(Color.white)
                        .symbolSize(30)
                        .annotation(position: .top) {
                            Text("\(Int(entry.moodLevel))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    RuleMark(y: .value("Great", 8))
                        .foregroundStyle(colors.moodColors[4].opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(alignment: .trailing, spacing: 0) {
                            Text("Great")
                                .font(.caption)
                                .foregroundColor(colors.moodColors[4])
                                .padding(.trailing, 10)
                        }
                    
                    RuleMark(y: .value("Low", 4))
                        .foregroundStyle(colors.moodColors[1].opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(alignment: .trailing, spacing: 0) {
                            Text("Low")
                                .font(.caption)
                                .foregroundColor(colors.moodColors[1])
                                .padding(.trailing, 10)
                        }
                }
                .chartYScale(domain: 1...10)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [2, 4, 6, 8, 10]) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 250)
                
                // Mood scale legend and explanation
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        ForEach(0..<colors.moodColors.count, id: \.self) { index in
                            VStack(spacing: 4) {
                                Rectangle()
                                    .fill(colors.moodColors[index])
                                    .frame(height: 6)
                                
                                if index == 0 || index == 2 || index == 4 {
                                    Text(getMoodName(for: index))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Text("This chart shows how your mood has changed over time. Higher points mean better moods, and you can see patterns like weekend happiness or mid-week stress.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
    
    private func getMoodName(for index: Int) -> String {
        switch index {
        case 0: return "Depressed"
        case 2: return "Neutral"
        case 4: return "Euphoric"
        default: return ""
        }
    }
}

// MARK: - Factor Impact Section
struct FactorImpactSection: View {
    let viewModel: MoodTrackerViewModel
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    
    var factorData: [(factor: String, positive: Int, negative: Int)] {
        // Get raw factor data without calculating impact scores
        var factorCounts: [String: (positive: Int, negative: Int)] = [:]
        
        for entry in viewModel.moodEntries {
            for (factor, impact) in entry.factors {
                if factorCounts[factor] == nil {
                    factorCounts[factor] = (positive: 0, negative: 0)
                }
                
                if impact == .positive {
                    factorCounts[factor]!.positive += 1
                } else {
                    factorCounts[factor]!.negative += 1
                }
            }
        }
        
        return factorCounts.map { (factor: $0.key, positive: $0.value.positive, negative: $0.value.negative) }
            .sorted { $0.positive + $0.negative > $1.positive + $1.negative }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mood Factors")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(colors.secondary)
            
            if factorData.isEmpty {
                Text("No factor data available yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach(factorData, id: \.factor) { item in
                        FactorRow(
                            factor: item.factor,
                            positive: item.positive,
                            negative: item.negative,
                            colors: colors
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct FactorRow: View {
    let factor: String
    let positive: Int
    let negative: Int
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    
    private var total: Int {
        positive + negative
    }
    
    private var positivePercentage: Double {
        total > 0 ? Double(positive) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(factor)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(total) entries")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 0) {
                // Positive section
                Rectangle()
                    .fill(colors.positive)
                    .frame(width: positivePercentage * UIScreen.main.bounds.width * 0.7, height: 24)
                    .overlay(
                        Text(positive > 0 ? "\(positive)" : "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.leading, 8),
                        alignment: .leading
                    )
                
                // Negative section
                Rectangle()
                    .fill(colors.negative)
                    .frame(width: (1-positivePercentage) * UIScreen.main.bounds.width * 0.7, height: 24)
                    .overlay(
                        Text(negative > 0 ? "\(negative)" : "")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 8),
                        alignment: .trailing
                    )
            }
            .cornerRadius(6)
            
            HStack {
                Circle()
                    .fill(colors.positive)
                    .frame(width: 8, height: 8)
                
                Text("Positive")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Circle()
                    .fill(colors.negative)
                    .frame(width: 8, height: 8)
                
                Text("Negative")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Weekly Averages Section
struct WeeklyAveragesSection: View {
    let viewModel: MoodTrackerViewModel
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color,
        gradient: [Color],
        moodColors: [Color]
    )
    @Binding var selectedIndex: Int?
    
    var lastFiveWeeks: [WeeklyAverageEntry] {
        let allData = viewModel.getWeeklyAverages()
        let sortedData = allData.sorted { $0.week > $1.week }
        return Array(sortedData.prefix(5))
    }

    var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Weekly Averages")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colors.secondary)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your mood averages over time")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(Array(lastFiveWeeks.enumerated()), id: \.element.id) { index, entry in
                            BarMark(
                                x: .value("Week", entry.week),
                                y: .value("Average", entry.average)
                            )
                            .foregroundStyle(
                                selectedIndex == index ?
                                LinearGradient(colors: colors.gradient, startPoint: .bottom, endPoint: .top) :
                                LinearGradient(colors: [colors.secondary.opacity(0.7), colors.secondary.opacity(0.9)], startPoint: .bottom, endPoint: .top)
                            )
                            .cornerRadius(8)
                        }
                        
                        RuleMark(y: .value("Neutral", 5))
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .trailing) {
                                Text("Neutral")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                    }
                    .chartYScale(domain: 1...10)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 12))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [2, 4, 6, 8, 10]) { value in
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geometry.frame(in: .local).minX
                                            if let (index, _) = findElement(at: x, proxy: proxy, geometry: geometry) {
                                                selectedIndex = index
                                            }
                                        }
                                        .onEnded { _ in
                                            selectedIndex = nil
                                        }
                                )
                        }
                    }
                    
                    // Selected week details
                    if let selectedIndex = selectedIndex, selectedIndex < lastFiveWeeks.count {
                        let selectedWeek = lastFiveWeeks[selectedIndex]
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Week \(selectedWeek.week)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(colors.secondary)
                                
                                Text("Average: \(String(format: "%.1f", selectedWeek.average))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: getWeekTrendIcon(for: selectedIndex))
                                .font(.system(size: 24))
                                .foregroundColor(getWeekTrendColor(for: selectedIndex))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }
        
        private func findElement(at xPosition: CGFloat, proxy: ChartProxy, geometry: GeometryProxy) -> (Int, WeeklyAverageEntry)? {
            let relativeXPosition = xPosition / geometry.size.width
            
            if let week = proxy.value(atX: relativeXPosition) as String? {
                if let index = lastFiveWeeks.firstIndex(where: { $0.week == week }) {
                    return (index, lastFiveWeeks[index])
                }
            }
            return nil
        }
        
        private func getWeekTrendIcon(for index: Int) -> String {
            guard index < lastFiveWeeks.count - 1 else { return "equal.circle.fill" }
            
            let currentAvg = lastFiveWeeks[index].average
            let previousAvg = lastFiveWeeks[index + 1].average
            
            if currentAvg > previousAvg + 0.5 {
                return "arrow.up.circle.fill"
            } else if currentAvg < previousAvg - 0.5 {
                return "arrow.down.circle.fill"
            } else {
                return "equal.circle.fill"
            }
        }
        
        private func getWeekTrendColor(for index: Int) -> Color {
            guard index < lastFiveWeeks.count - 1 else { return .gray }
            
            let currentAvg = lastFiveWeeks[index].average
            let previousAvg = lastFiveWeeks[index + 1].average
            
            if currentAvg > previousAvg + 0.5 {
                return colors.positive
            } else if currentAvg < previousAvg - 0.5 {
                return colors.negative
            } else {
                return .gray
            }
        }
    }

// MARK: - Preview
#Preview {
    // Create a simplified preview that shows the design
    ZStack {
        Color(red: 250/255, green: 248/255, blue: 245/255).ignoresSafeArea()
        
        // Show the NoDataView for preview purposes
        NoDataView()
            .padding(.top, 150)
            .background(
                VStack(spacing: 0) {
                    // Preview header
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 147/255, green: 112/255, blue: 219/255),
                            Color(red: 126/255, green: 188/255, blue: 237/255)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 150)
                    .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                    .ignoresSafeArea(edges: .top)
                    
                    Spacer()
                }
            )
    }
}
