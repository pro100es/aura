import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Что-то пошло не так")
                .font(.auraHeadline)
                .foregroundStyle(.auraTextPrimary)

            Text(error.localizedDescription)
                .font(.auraCaption)
                .foregroundStyle(.auraTextSecondary)
                .multilineTextAlignment(.center)

            if let retryAction {
                AuraSecondaryButton(title: "Попробовать снова", icon: "arrow.clockwise", action: retryAction)
            }
        }
        .padding(Spacing.xl)
    }
}
