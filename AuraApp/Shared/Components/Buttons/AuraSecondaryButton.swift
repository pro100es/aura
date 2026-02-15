import SwiftUI

struct AuraSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                }
                Text(title).font(.auraCallout)
            }
            .foregroundStyle(.auraTextPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }
}
