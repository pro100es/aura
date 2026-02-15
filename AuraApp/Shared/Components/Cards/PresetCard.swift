import SwiftUI

struct PresetCard: View {
    let preset: Preset
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                presetImage
                textContent
            }
            .background(.ultraThinMaterial)
            .cornerRadius(CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var presetImage: some View {
        if let url = preset.iconURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ShimmerView()
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Color.auraSurface
                @unknown default:
                    ShimmerView()
                }
            }
            .frame(height: 180)
            .clipped()
        } else {
            Color.auraSurface
                .frame(height: 180)
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(preset.name).font(.auraHeadline).foregroundStyle(Color.auraTextPrimary)
                Spacer()
                if preset.isPremium {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 14))
                }
            }
            if let desc = preset.description {
                Text(desc)
                    .font(.auraCaption)
                    .foregroundStyle(Color.auraTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(Spacing.md)
    }
}
