import SwiftUI

struct OnboardingContainerView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userMode") private var userModeRaw: String = PresetMode.persona.rawValue
    @State private var step = 0
    @State private var selectedMode: PresetMode = .persona

    var body: some View {
        Group {
            switch step {
            case 0:
                OnboardingIntroView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { step = 1 }
                }
            case 1:
                ModeSelectionView(selectedMode: $selectedMode) {
                    completeOnboarding()
                }
            default:
                EmptyView()
            }
        }
        .onChange(of: selectedMode) { _, newValue in
            userModeRaw = newValue.rawValue
        }
    }

    private func completeOnboarding() {
        userModeRaw = selectedMode.rawValue
        hasCompletedOnboarding = true
    }
}
