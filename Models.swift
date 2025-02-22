import SwiftUI

// In Models.swift

enum FactorImpact: String, Codable {
    case positive = "positive"
    case negative = "negative"
    
    // Add an initializer to handle potential decoding issues
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue.lowercased() {
        case "positive":
            self = .positive
        case "negative":
            self = .negative
        default:
            // Provide a default value if the decoded value is unexpected
            self = .positive
        }
    }
}

enum AppScreen {
    case home
    case stats
    case calendar
    case profile
}

struct MoodFactorInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    
    // Implementing Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MoodFactorInfo, rhs: MoodFactorInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// Add these new structures to Models.swift
struct Achievement: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let type: AchievementType
    var isUnlocked: Bool = false
    let color: Color
}

enum AchievementType {
    case firstLog
    case streak
    case factorUse
    case consistency
    case moodVariety
}

let achievements = [
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
        title: "Sleep Tracker",
        description: "Log sleep impact for 5 days in a row",
        iconName: "bed.double.fill",
        type: .consistency,
        color: Color(red: 147/255, green: 112/255, blue: 219/255)
    ),
    Achievement(
        title: "Mood Range",
        description: "Experience the full range of moods",
        iconName: "chart.bar.fill",
        type: .moodVariety,
        color: Color(red: 70/255, green: 130/255, blue: 180/255)
    )
]
