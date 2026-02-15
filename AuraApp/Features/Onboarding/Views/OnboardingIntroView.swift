import SwiftUI

struct OnboardingIntroView: View {
    let onComplete: () -> Void
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                gradientOverlay
                textOverlay

                Spacer()

                AuraButton(title: "Далее") {
                    onComplete()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                onComplete()
            }
            .font(.auraCallout)
            .foregroundStyle(Color.auraTextSecondary)
            .padding(Spacing.lg)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).delay(0.5)) { phase = 1 }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.auraBackground.opacity(0), .auraBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 200)
    }

    private var textOverlay: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(Color.auraAccent)
            Text("Ваш контент.")
                .font(.auraTitle)
                .foregroundStyle(Color.auraTextPrimary)
            Text("В любом месте. В любое время.")
                .font(.auraTitle2)
                .foregroundStyle(Color.auraTextSecondary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
    }
}
