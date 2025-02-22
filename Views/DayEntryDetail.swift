import SwiftUI

struct DayEntryDetail: View {
    let entry: MoodEntry
    @Environment(\.dismiss) private var dismiss
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255)
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Mood Level Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood Level")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(colors.secondary)
                        
                        HStack {
                            Text(String(format: "%.1f", entry.moodLevel))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(getMoodColor(for: entry.moodLevel))
                            
                            Spacer()
                            
                            Image(systemName: getMoodIcon(for: entry.moodLevel))
                                .font(.system(size: 34))
                                .foregroundColor(getMoodColor(for: entry.moodLevel))
                        }
                        .padding()
                        .background(colors.buttonBackground)
                        .cornerRadius(16)
                    }
                    
                    // Factors Section
                    if !entry.factors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mood Factors")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(colors.secondary)
                            
                            VStack(spacing: 12) {
                                ForEach(Array(entry.factors.keys.sorted()), id: \.self) { factor in
                                    HStack {
                                        Text(factor)
                                            .font(.system(size: 17))
                                        
                                        Spacer()
                                        
                                        Text(entry.factors[factor] == .positive ? "Positive" : "Negative")
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                entry.factors[factor] == .positive ?
                                                colors.positive : colors.negative
                                            )
                                            .cornerRadius(8)
                                    }
                                    .padding()
                                    .background(colors.buttonBackground)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // Note Section
                    if !entry.note.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Note")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(colors.secondary)
                            
                            Text(entry.note)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colors.buttonBackground)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(colors.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(formattedDate(entry.date))
                        .font(.headline)
                        .foregroundColor(colors.secondary)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func getMoodColor(for level: Double) -> Color {
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
    
    private func getMoodIcon(for level: Double) -> String {
        switch level {
        case 8...10: return "sun.max.fill"
        case 6...8: return "sun.and.horizon.fill"
        case 4...6: return "cloud.sun.fill"
        case 2...4: return "cloud.fill"
        default: return "cloud.rain.fill"
        }
    }
}

#Preview {
    DayEntryDetail(
        entry: MoodEntry(
            date: Date(),
            moodLevel: 8.5,
            factors: ["Exercise": .positive, "Work": .negative],
            note: "Had a great workout today but work was stressful."
        )
    )
}
