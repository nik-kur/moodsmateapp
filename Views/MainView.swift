import SwiftUI
import FirebaseAuth

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MoodTrackerViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var storeManager = StoreManager()

    
    var body: some View {
        if !networkMonitor.isConnected {
            OfflineView()
        } else {
            ZStack {  // Outer ZStack for tutorial overlay
                NavigationView {
                    ZStack {  // Inner ZStack for content and achievement notifications
                        TabView {
                            HomeView()
                                .tabItem {
                                    Label("Home", systemImage: "house.fill")
                                }
                                
                            
                            CalendarView()
                                .tabItem {
                                    Label("Calendar", systemImage: "calendar")
                                }
                               
                            
                            AnalyticsView()
                                .tabItem {
                                    Label("Analytics", systemImage: "chart.bar.fill")
                                }
                                
                            
                            AchievementsView()
                                .tabItem {
                                    Label("Achievements", systemImage: "trophy.fill")
                                }
                               
                            
                            ProfileView()
                                .tabItem {
                                    Label("Profile", systemImage: "person.circle")
                                }
                                
                        }
                        .environmentObject(viewModel)
                        .onReceive(viewModel.$moodEntries) { entries in
                            print("MoodEntries updated: \(entries.count) entries")
                        }
                        .onAppear {
                            // Force a fresh load of data when app appears
                            if Auth.auth().currentUser != nil {
                                viewModel.fetchMoodEntries()
                            }
                        }
                        
                        // Achievement Notification Overlay
                        VStack {
                            if viewModel.showingAchievementNotification,
                               let achievement = viewModel.lastUnlockedAchievement {
                                AchievementNotification(
                                    achievement: achievement,
                                    isPresented: $viewModel.showingAchievementNotification
                                )
                                .transition(.move(edge: .top))
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.showingAchievementNotification)
                                .padding(.top, getSafeAreaInsets().top)
                            }
                            Spacer()
                        }
                        .ignoresSafeArea()
                    }
                }
                
                // Tutorial Overlay
                
            }
            
        }
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return .zero
        }
        return window.safeAreaInsets
    }
}
