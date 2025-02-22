import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseInAppMessaging
import GoogleSignIn
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Make sure Firebase is only configured once
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Add error handling for Google Sign-In configuration
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct MoodTrackerApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasCompletedQuestionnaire") private var hasCompletedQuestionnaire = false
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenWelcome {
                    WelcomeView()
                        .transition(.opacity)
                        .zIndex(1)
                } else if !hasCompletedQuestionnaire {
                    QuestionnaireView(showQuestionnaire: $hasCompletedQuestionnaire)
                        .transition(.opacity)
                        .zIndex(0)
                } else {
                    NavigationView {
                        Group {
                            if !authViewModel.isLoggedIn {
                                AuthenticationView()
                            } else if authViewModel.shouldShowInitialProfileSetup {
                                InitialProfileSetupView()
                            } else if authViewModel.isProfileComplete {
                                MainView()
                            } else {
                                ProfileView()
                            }
                        }
                        .fullScreenCover(isPresented: $authViewModel.shouldShowAccountDeletedMessage) {
                            AccountDeletedView()
                        }
                    }
                    .environmentObject(authViewModel)
                    .transition(.opacity)
                    .zIndex(0)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasSeenWelcome)
            .animation(.easeInOut(duration: 0.3), value: hasCompletedQuestionnaire)
           
        }
    }
}
