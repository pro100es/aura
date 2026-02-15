import SwiftUI

struct ResultsCarouselView: View {
    let generation: GenerationStatus
    let onDismiss: () -> Void

    @State private var currentIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let outputs = generation.outputs, !outputs.isEmpty {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(outputs.enumerated()), id: \.offset) { index, output in
                            resultImage(output)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .onChange(of: currentIndex) { _, _ in HapticManager.selection() }
                } else {
                    Text("Нет результатов")
                        .font(.auraBody)
                        .foregroundStyle(Color.auraTextSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                actionsBar
            }
            .background(Color.auraBackground)
            .navigationTitle("Результат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") {
                        onDismiss()
                    }
                    .foregroundStyle(Color.auraAccent)
                }
            }
        }
    }

    @ViewBuilder
    private func resultImage(_ output: GenerationStatus.GenerationOutput) -> some View {
        Group {
            if let urlString = output.url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fit)
                    case .failure: Color.auraSurface
                    default: ShimmerView()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    AIBadge().padding(Spacing.sm)
                }
            } else {
                Color.auraSurface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.md)
    }

    private var actionsBar: some View {
        HStack(spacing: Spacing.lg) {
            if let outputs = generation.outputs,
               currentIndex < outputs.count,
               let urlStr = outputs[currentIndex].url,
               let url = URL(string: urlStr) {
                Button {
                    HapticManager.impact(.light)
                    // TODO: Save to Photos
                } label: {
                    Label("Сохранить", systemImage: "square.and.arrow.down")
                        .font(.auraCallout)
                }
                .foregroundStyle(Color.auraTextPrimary)

                ShareLink(item: url) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .font(.auraCallout)
                }
                .foregroundStyle(Color.auraTextPrimary)
            }

            Spacer()

            AuraSecondaryButton(title: "Сгенерировать ещё", icon: "sparkles") {
                onDismiss()
            }
        }
        .padding(Spacing.lg)
        .background(Color.auraSurface)
    }
}

struct AIBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold))
            Text("AI").font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.purple.opacity(0.8)))
    }
}
