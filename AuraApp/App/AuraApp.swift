import SwiftUI

@main
struct AuraApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootView(hasCompletedOnboarding: hasCompletedOnboarding)
                .onChange(of: hasCompletedOnboarding) { _, _ in }
        }
    }
}

struct RootView: View {
    let hasCompletedOnboarding: Bool
    @State private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingContainerView()
            } else if !authManager.isAuthenticated {
                AuthView(onAuthenticated: {})
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let token = authManager.token {
                APIService.shared.setAuthToken(token)
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PresetGalleryView()
                .tabItem { Label("Создать", systemImage: "sparkles") }
                .tag(0)
            GalleryView()
                .tabItem { Label("Галерея", systemImage: "photo.on.rectangle.angled") }
                .tag(1)
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.fill") }
                .tag(2)
        }
        .tint(Color.auraAccent)
    }
}
