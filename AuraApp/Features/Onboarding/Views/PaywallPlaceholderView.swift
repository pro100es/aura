import SwiftUI

struct PaywallPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)

                Text("Pro подписка")
                    .font(.auraTitle)
                    .foregroundStyle(.auraTextPrimary)

                Text("Разблокируйте все пресеты и безлимитные генерации")
                    .font(.auraBody)
                    .foregroundStyle(.auraTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                AuraButton(title: "Подключить (скоро)") {
                    dismiss()
                }
                .padding(.horizontal, Spacing.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.auraBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(.auraTextSecondary)
                }
            }
        }
    }
}
