import SwiftUI

struct ModeSelectionView: View {
    @Binding var selectedMode: PresetMode
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.sm) {
                Text("Как будете использовать?")
                    .font(.auraTitle)
                    .foregroundStyle(Color.auraTextPrimary)
                Text("Выберите основную цель")
                    .font(.auraBody)
                    .foregroundStyle(Color.auraTextSecondary)
            }
            .padding(.top, Spacing.xxl)

            VStack(spacing: Spacing.md) {
                ForEach(PresetMode.allCases, id: \.self) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode
                    ) {
                        HapticManager.impact(.light)
                        selectedMode = mode
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            AuraButton(title: "Продолжить") {
                onComplete()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(Color.auraBackground)
    }
}

struct ModeCard: View {
    let mode: PresetMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? Color.auraAccent : Color.auraTextSecondary)
                    .frame(width: 48, alignment: .center)

                Text(mode.displayName)
                    .font(.auraHeadline)
                    .foregroundStyle(Color.auraTextPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.auraAccent)
                }
            }
            .padding(Spacing.lg)
            .background(isSelected ? Color.auraAccent.opacity(0.15) : Color.auraSurface)
            .cornerRadius(CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .strokeBorder(isSelected ? Color.auraAccent : .white.opacity(0.12), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
