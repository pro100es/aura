import SwiftUI

struct GenerationProcessView: View {
    let generationId: String
    @State private var status: GenerationStatus?
    @State private var completedStatus: GenerationStatus?
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if let status {
                statusView(status)
            } else if let err = errorMessage {
                ErrorView(error: APIError.serverError(err)) {
                    Task { await poll() }
                }
            } else {
                ProgressView().tint(Color.auraAccent).scaleEffect(1.5)
                Text("Загрузка...").font(.auraBody).foregroundStyle(Color.auraTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if status?.status == "processing" || status?.status == "starting" {
                    Button("Отменить") { cancelAndDismiss() }
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
        .fullScreenCover(item: $completedStatus) { generation in
            ResultsCarouselView(generation: generation, onDismiss: { completedStatus = nil; dismiss() })
        }
    }

    private func statusView(_ s: GenerationStatus) -> some View {
        VStack(spacing: Spacing.lg) {
            ProgressView().tint(Color.auraAccent).scaleEffect(1.5)
            Text(statusMessage(s.status))
                .font(.auraHeadline)
                .foregroundStyle(Color.auraTextPrimary)
                .multilineTextAlignment(.center)
            Text("Обычно это занимает 20–30 секунд")
                .font(.auraCaption)
                .foregroundStyle(Color.auraTextSecondary)
        }
        .padding(Spacing.xl)
        .onChange(of: s.status) { _, newValue in
            if newValue == "succeeded" {
                HapticManager.notification(.success)
                completedStatus = s
            } else if newValue == "failed" {
                HapticManager.notification(.error)
                errorMessage = s.error?.message ?? "Ошибка генерации"
            }
        }
    }

    private func statusMessage(_ status: String) -> String {
        switch status {
        case "starting": return "Загружаем фото..."
        case "processing": return "Рендерим текстуры..."
        case "succeeded": return "Готово!"
        case "failed": return "Ошибка"
        default: return "Обработка..."
        }
    }

    private func startPolling() {
        pollTask = Task {
            for _ in 0 ..< 60 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await poll()
                guard let s = status else { continue }
                if s.status == "succeeded" || s.status == "failed" { return }
            }
        }
    }

    private func poll() async {
        do {
            let s = try await APIService.shared.getGeneration(id: generationId)
            await MainActor.run { status = s }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func cancelAndDismiss() {
        pollTask?.cancel()
        Task {
            try? await APIService.shared.cancelGeneration(id: generationId)
            await MainActor.run { dismiss() }
        }
    }
}
