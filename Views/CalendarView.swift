import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var showingEntryDetail = false
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private let calendar = Calendar.current
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255)
    )
    
    var body: some View {
        if !networkMonitor.isConnected {
                OfflineView()
            } else {
        ZStack {
            colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Calendar")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Your mood journey")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "calendar")
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
                    
                    VStack(spacing: 20) {
                        // Month Navigation
                        HStack {
                            Button(action: {
                                withAnimation {
                                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(colors.secondary)
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            
                            Spacer()
                            
                            Text(monthYearString(from: selectedMonth))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colors.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(colors.secondary)
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Weekday Headers
                        HStack {
                            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                                Text(day)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(colors.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Calendar Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(daysInMonth(), id: \.self) { date in
                                if let date = date {
                                    DayCell(
                                        date: date,
                                        moodEntry: viewModel.getEntry(for: date),
                                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date())
                                    )
                                    .onTapGesture {
                                        if viewModel.getEntry(for: date) != nil {
                                            selectedDate = date
                                            showingEntryDetail = true
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fill)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 90)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingEntryDetail) {
            if let selectedDate = selectedDate,
               let entry = viewModel.getEntry(for: selectedDate) {
                DayEntryDetail(entry: entry)
            }
        }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingSpaces = firstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        let trailingSpaces = 7 - (days.count % 7)
        if trailingSpaces < 7 {
            days.append(contentsOf: Array(repeating: nil, count: trailingSpaces))
        }
        
        return days
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

struct DayCell: View {
    let date: Date
    let moodEntry: MoodEntry?
    let isSelected: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            if let entry = moodEntry {
                Circle()
                    .fill(getMoodColor(for: entry.moodLevel))
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? .white : .clear, lineWidth: 2)
                    )
            }
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: moodEntry != nil ? .bold : .regular))
                .foregroundColor(moodEntry != nil ? .white : .primary)
        }
        .aspectRatio(1, contentMode: .fill)
        .frame(height: 45) // Add fixed height
                .frame(maxWidth: .infinity) // Ensure width fills space
    }
    
    private func getMoodColor(for level: Double) -> Color {
        // Match the colors from your mood levels
        switch level {
        case 8...10:
            return Color(red: 255/255, green: 215/255, blue: 0/255)
        case 6...8:
            return Color(red: 98/255, green: 182/255, blue: 183/255)
        case 4...6:
            return Color(red: 135/255, green: 206/255, blue: 235/255)
        case 2...4:
            return Color(red: 176/255, green: 196/255, blue: 222/255)
        default:
            return Color(red: 169/255, green: 169/255, blue: 169/255)
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(MoodTrackerViewModel())
}
