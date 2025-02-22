import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

struct MoodEntry: Codable, Identifiable {
    var id: String?
    let date: Date
    let moodLevel: Double
    let factors: [String: FactorImpact]
    let note: String
    
    init(id: String? = nil, date: Date, moodLevel: Double, factors: [String: FactorImpact], note: String) {
        self.id = id
        self.date = date
        self.moodLevel = moodLevel
        self.factors = factors
        self.note = note
    }
    
    // Add CodingKeys to handle the custom FactorImpact enum
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case moodLevel
        case factors
        case note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        moodLevel = try container.decode(Double.self, forKey: .moodLevel)
        note = try container.decode(String.self, forKey: .note)
        
        // Custom decoding for factors to handle FactorImpact enum
        let factorsDict = try container.decode([String: String].self, forKey: .factors)
        factors = factorsDict.mapValues { FactorImpact(rawValue: $0) ?? .positive }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(moodLevel, forKey: .moodLevel)
        try container.encode(note, forKey: .note)
        
        // Custom encoding for factors
        let factorsDict = factors.mapValues { $0.rawValue }
        try container.encode(factorsDict, forKey: .factors)
    }
}

// Analytics data structures
struct MoodTrendEntry: Identifiable {
    let id = UUID()
    let date: Date
    let moodLevel: Double
}

struct FactorImpactEntry: Identifiable {
    let id = UUID()
    let name: String
    let impact: Double
}

struct WeeklyAverageEntry: Identifiable {
    let id = UUID()
    let week: String
    let average: Double
}

final class MoodTrackerViewModel: ObservableObject {
   
    // Published properties for UI
    @Published var moodLevel: Double = 5.0
    @Published var currentScreen: AppScreen = .home
    @Published var selectedFactors: [String: FactorImpact] = [:]
    @Published var noteText: String = ""
    @Published var showingAchievementNotification = false
    @Published var lastUnlockedAchievement: Achievement?
    @Published var showDuplicateEntryAlert = false
    @Published var pendingMoodEntry: MoodEntry?
   
    
    // Achievement tracking
    @Published var unlockedAchievements: Set<UUID> = []
    @Published var achievements: [Achievement] = []
    
    // Data storage
    @Published private(set) var moodEntries: [MoodEntry] = []
    private var streakCount: Int = 0
    private var usedFactors: Set<String> = []
    
    @Published var errorMessage: String?
    @Published var showError = false
    private let networkMonitor = NetworkMonitor()
    
    // Firestore reference
    private let db = Firestore.firestore()
    

    
    init() {
        setupAchievements()
        
        // Fetch real entries if user is logged in
        if Auth.auth().currentUser != nil {
            fetchMoodEntries()
        }
    }
    
    // MARK: - Firestore Data Management
    
    func saveMood() {
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            showError = true
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No logged-in user"
            showError = true
            return
        }
        
        let newEntry = MoodEntry(
            date: Date(),
            moodLevel: moodLevel,
            factors: selectedFactors,
            note: noteText
        )
        
        let calendar = Calendar.current
        if let todayEntry = moodEntries.first(where: {
            calendar.isDate($0.date, inSameDayAs: Date())
        }) {
            // ✅ An entry for today already exists, ask user to confirm replacement
            pendingMoodEntry = newEntry
            showDuplicateEntryAlert = true
        } else {
            // ✅ No existing entry, proceed with saving
            saveEntryToFirebase(entry: newEntry, userId: currentUser.uid, replaceExisting: false)
        }
    }

    
    // Make sure this properly updates both Firebase and local array
    func confirmSaveExistingDayMood() {
        guard let entry = pendingMoodEntry, let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let calendar = Calendar.current
        let todayEntries = moodEntries.filter {
            calendar.isDate($0.date, inSameDayAs: Date()) // ✅ Get ALL entries for today
        }

        if let latestEntry = todayEntries.max(by: { $0.date < $1.date }), let latestEntryId = latestEntry.id {
            // ✅ Delete the most recent entry for today before saving the new one
            db.collection("users")
                .document(userId)
                .collection("moodEntries")
                .document(latestEntryId)
                .delete { [weak self] error in
                    if error == nil {
                        // ✅ Remove the old entry from local list
                        self?.moodEntries.removeAll { $0.id == latestEntryId }

                        // ✅ Save the new entry
                        self?.saveEntryToFirebase(entry: entry, userId: userId, replaceExisting: true)
                    } else {
                        self?.errorMessage = "Error replacing entry: \(error!.localizedDescription)"
                        self?.showError = true
                    }
                }
        } else {
            // ✅ If no existing entry found, just save the new one
            saveEntryToFirebase(entry: entry, userId: userId, replaceExisting: false)
        }

        pendingMoodEntry = nil
    }


    
    private func saveEntryToFirebase(entry: MoodEntry, userId: String, replaceExisting: Bool) {
        do {
            let documentRef = db.collection("users")
                .document(userId)
                .collection("moodEntries")
                .document() // Firestore auto-generates an ID

            try documentRef.setData(from: entry) { [weak self] error in
                if error == nil {
                    DispatchQueue.main.async {
                        self?.moodLevel = 5.0
                        self?.selectedFactors.removeAll()
                        self?.noteText = ""

                        if replaceExisting {
                            self?.moodEntries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
                        }

                        self?.moodEntries.append(entry)
                        
                        // ✅ Manually trigger an update to refresh AnalyticsView
                        self?.objectWillChange.send()
                    }
                } else if let error = error {
                    self?.errorMessage = "Error saving entry: \(error.localizedDescription)"
                    self?.showError = true
                }
            }
        } catch {
            errorMessage = "Error encoding mood entry: \(error.localizedDescription)"
            showError = true
        }
    }


    
    func fetchMoodEntries() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No logged-in user")
            return
        }

        db.collection("users")
          .document(currentUser.uid)
          .collection("moodEntries")
          .order(by: "date", descending: true)
          .getDocuments { (querySnapshot, error) in
              if let error = error {
                  print("Error fetching mood entries: \(error.localizedDescription)")
                  return
              }

              guard let documents = querySnapshot?.documents else {
                  print("No mood entries found in Firebase.")
                  return
              }

              let updatedMoodEntries = documents.compactMap { document -> MoodEntry? in
                  do {
                      var entry = try document.data(as: MoodEntry.self)
                      entry.id = document.documentID  // ✅ Assign ID directly
                      return entry
                  } catch {
                      print("Error decoding mood entry: \(error.localizedDescription)")
                      return nil
                  }
              }

              DispatchQueue.main.async {
                  self.objectWillChange.send()  // ✅ Ensure UI refresh
                  self.moodEntries = updatedMoodEntries
              }
          }
    }



    
    // MARK: - Analytics Methods
    
    func getMoodTrendData(for timeRange: TimeRange) -> [MoodTrendEntry] {
        let calendar = Calendar.current
        let today = Date()

        // Always get Monday of the current week
        var startOfWeek: Date = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

        // Always get the following Sunday
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today

        let filteredEntries = moodEntries.filter { entry in
            switch timeRange {
            case .week:
                return entry.date >= startOfWeek && entry.date <= endOfWeek // ✅ Always within Monday to Sunday
            case .month:
                return calendar.dateComponents([.day], from: entry.date, to: today).day ?? 0 <= 30
            }
        }

        return filteredEntries
            .sorted { $0.date < $1.date }
            .map { MoodTrendEntry(date: $0.date, moodLevel: $0.moodLevel) }
    }






    func getFactorImpactData() -> [FactorImpactEntry] {
       guard networkMonitor.isConnected else {
           errorMessage = "No internet connection"
           showError = true
           return []
       }
       
       var factorImpacts: [String: (positive: Int, negative: Int)] = [:]
       
       for entry in moodEntries {
           for (factor, impact) in entry.factors {
               if factorImpacts[factor] == nil {
                   factorImpacts[factor] = (positive: 0, negative: 0)
               }
               
               if impact == .positive {
                   factorImpacts[factor]!.positive += 1
               } else {
                   factorImpacts[factor]!.negative += 1
               }
           }
       }
       
       return factorImpacts.map { factor, counts in
           let netImpact = Double(counts.positive - counts.negative)
           return FactorImpactEntry(name: factor, impact: netImpact)
       }.sorted { abs($0.impact) > abs($1.impact) }
    }

    func getWeeklyAverages() -> [WeeklyAverageEntry] {
       guard networkMonitor.isConnected else {
           errorMessage = "No internet connection"
           showError = true
           return []
       }
       
       let calendar = Calendar.current
       var weeklyMoods: [String: [Double]] = [:]
       
       for entry in moodEntries {
           let weekComponent = calendar.component(.weekOfYear, from: entry.date)
           let month = calendar.component(.month, from: entry.date)
           let weekKey = "W\(weekComponent)\n\(getMonthAbbreviation(month))"
           
           weeklyMoods[weekKey, default: []].append(entry.moodLevel)
       }
       
       return weeklyMoods.map { week, moods in
           let average = moods.reduce(0.0, +) / Double(moods.count)
           return WeeklyAverageEntry(week: week, average: average)
       }
       .sorted { $0.week < $1.week }
    }
    
    private func getMonthAbbreviation(_ month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return dateFormatter.string(from: date)
    }
    
    func getMoodInsights() -> [String] {
        var insights: [String] = []
        
        // Factor analysis - Count all factor occurrences
        var factorCounts: [String: (positive: Int, negative: Int)] = [:]
        
        for entry in moodEntries {
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
        
        // Find highest positive and negative impact factors
        let maxPositive = factorCounts.values.map { $0.positive }.max() ?? 0
        let maxNegative = factorCounts.values.map { $0.negative }.max() ?? 0

        let topPositiveFactors = factorCounts
            .filter { $0.value.positive == maxPositive && maxPositive > 0 }
            .map { "\($0.key) (\($0.value.positive))" }
        
        let topNegativeFactors = factorCounts
            .filter { $0.value.negative == maxNegative && maxNegative > 0 }
            .map { "\($0.key) (\($0.value.negative))" }

        // Add insights to the list
        if !topPositiveFactors.isEmpty {
            insights.append("Top positive factors: \(topPositiveFactors.joined(separator: ", "))")
        }
        if !topNegativeFactors.isEmpty {
            insights.append("Top negative factors: \(topNegativeFactors.joined(separator: ", "))")
        }

        // Weekly Mood Average Analysis
        let trend = getMoodTrendData(for: .week)
        if trend.count >= 7 {
            let recentAvg = trend.map { $0.moodLevel }.reduce(0, +) / Double(trend.count)
            insights.append("Your average mood for the past week is \(String(format: "%.1f", recentAvg))")
        }

        return insights
    }

    
    // MARK: - Entry Management
    
    func getEntry(for date: Date) -> MoodEntry? {
        moodEntries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func toggleFactor(_ factor: String, impact: FactorImpact) {
        if selectedFactors[factor] == impact {
            selectedFactors.removeValue(forKey: factor)
        } else {
            selectedFactors[factor] = impact
        }
    }
    
    func getFactorImpact(_ factor: String) -> FactorImpact? {
        selectedFactors[factor]
    }
    
    // MARK: - Achievement Methods
    
    private func checkAchievements() {
        print("Checking achievements: \(moodEntries.count) entries")
        
        // First entry achievement
        if moodEntries.count == 1 {
            unlockAchievement(type: .firstLog)
        }
        
        // Streak achievements
        updateStreakCount()
        if streakCount >= 7 {
            unlockAchievement(type: .streak)
        }
        if streakCount >= 30 {
            unlockAchievement(type: .streak)
        }
        
        // Factor achievements
        for factor in usedFactors {
            if factor == "Exercise" {
                unlockAchievement(type: .factorUse)
            }
        }
        
        checkMoodVariety()
    }
    
    private func unlockAchievement(type: AchievementType) {
        if let achievement = achievements.first(where: { $0.type == type }),
           !unlockedAchievements.contains(achievement.id) {
            print("Unlocking achievement: \(achievement.title)")
            unlockedAchievements.insert(achievement.id)
            lastUnlockedAchievement = achievement
            
            DispatchQueue.main.async {
                self.showingAchievementNotification = true
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showingAchievementNotification = false
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateStreakCount() {
        guard !moodEntries.isEmpty else { return }
        
        let calendar = Calendar.current
        let sortedEntries = moodEntries.sorted { $0.date < $1.date }
        
        var currentStreak = 1
        var previousDate = sortedEntries[0].date
        
        for entry in sortedEntries.dropFirst() {
            let daysBetween = calendar.dateComponents([.day], from: previousDate, to: entry.date).day ?? 0
            
            if daysBetween == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            
            previousDate = entry.date
        }
        
        streakCount = currentStreak
    }
    
    private func checkMoodVariety() {
        let uniqueMoodLevels = Set(moodEntries.map { entry in
            switch entry.moodLevel {
            case 1...2: return "Very Low"
            case 2...4: return "Low"
            case 4...6: return "Neutral"
            case 6...8: return "High"
            case 8...10: return "Very High"
            default: return "Unknown"
            }
        })
        
        if uniqueMoodLevels.count >= 5 {
            unlockAchievement(type: .moodVariety)
        }
    }
    
    private func setupAchievements() {
        achievements = [
            Achievement(
                title: "First Step",
                description: "Log your first mood entry",
                iconName: "star.fill",
                type: .firstLog,
                color: Color(red: 255/255, green: 215/255, blue: 0/255)
            ),
            Achievement(
                title: "Week Warrior",
                description: "Complete a 7-day logging streak",
                iconName: "flame.fill",
                type: .streak,
                color: Color(red: 255/255, green: 140/255, blue: 0/255)
            ),
            Achievement(
                title: "Monthly Master",
                description: "Complete a 30-day logging streak",
                iconName: "crown.fill",
                type: .streak,
                color: Color(red: 255/255, green: 165/255, blue: 0/255)
            ),
            Achievement(
                title: "Exercise Explorer",
                description: "Use the Exercise factor for the first time",
                iconName: "figure.run",
                type: .factorUse,
                color: Color(red: 50/255, green: 205/255, blue: 50/255)
            ),
            Achievement(
                title: "Mood Range",
                description: "Experience the full range of moods",
                iconName: "chart.bar.fill",
                type: .moodVariety,
                color: Color(red: 70/255, green: 130/255, blue: 180/255)
            )
        ]
    }
    
    private func setupMockData() {
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in (-30...0).reversed() {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let mockEntry = MoodEntry(
                    date: date,
                    moodLevel: Double.random(in: 3...9),
                    factors: [
                        "Exercise": Bool.random() ? .positive : .negative,
                        "Sleep": Bool.random() ? .positive : .negative
                    ],
                    note: "Mock entry for testing"
                )
                moodEntries.append(mockEntry)
            }
        }
    }
    
    // MARK: - Logout Method
    
    func logout() {
        do {
            try Auth.auth().signOut()
            // Reset view model state
            moodEntries.removeAll()
            unlockedAchievements.removeAll()
            selectedFactors.removeAll()
            noteText = ""
            moodLevel = 5.0
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
