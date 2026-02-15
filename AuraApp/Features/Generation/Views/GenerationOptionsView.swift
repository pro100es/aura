import SwiftUI

struct GenerationOptionsView: View {
    let preset: Preset
    let image: UIImage
    let onStart: () -> Void

    @State private var aspectRatio: AspectRatio = .fourFive
    @State private var batchSize: Int = 4
    @State private var customPrompt: String = ""
    @State private var navigateToProcess = false
    @State private var generationId: String?

    enum AspectRatio: String, CaseIterable {
        case oneOne = "1:1"
        case fourFive = "4:5"
        case sixteenNine = "16:9"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    previewSection
                    optionsSection
                    Spacer(minLength: Spacing.xxl)
                }
                .padding(Spacing.lg)
            }
            .background(Color.auraBackground)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onStart() }
                        .foregroundStyle(.auraAccent)
                }
            }
            .navigationDestination(item: $generationId) { id in
                GenerationProcessView(generationId: id)
            }
        }
    }

    private var previewSection: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .cornerRadius(CornerRadius.small)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Соотношение сторон")
                    .font(.auraCaption)
                    .foregroundStyle(.auraTextSecondary)
                Picker("", selection: $aspectRatio) {
                    ForEach(AspectRatio.allCases, id: \.self) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Варианты (1–4)")
                    .font(.auraCaption)
                    .foregroundStyle(.auraTextSecondary)
                Stepper(value: $batchSize, in: 1 ... 4) {
                    Text("\(batchSize)")
                        .font(.auraHeadline)
                        .foregroundStyle(.auraTextPrimary)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Дополнительное описание (опционально)")
                    .font(.auraCaption)
                    .foregroundStyle(.auraTextSecondary)
                TextField("Мягкий свет, тёплые тона...", text: $customPrompt, axis: .vertical)
                    .font(.auraBody)
                    .foregroundStyle(.auraTextPrimary)
                    .lineLimit(3 ... 6)
                    .padding(Spacing.md)
                    .background(Color.auraSurface)
                    .cornerRadius(CornerRadius.small)
            }

            GenerationStartButton(
                preset: preset,
                image: image,
                aspectRatio: aspectRatio.rawValue,
                batchSize: batchSize,
                customPrompt: customPrompt.isEmpty ? nil : customPrompt
            ) { id in
                generationId = id
            }
        }
    }
}

struct GenerationStartButton: View {
    let preset: Preset
    let image: UIImage
    let aspectRatio: String
    let batchSize: Int
    let customPrompt: String?
    let onStarted: (String) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.auraCaption)
                    .foregroundStyle(.red)
            }
            AuraButton(title: "Создать фото", isLoading: isLoading) {
                await startGeneration()
            }
        }
        .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    private func startGeneration() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let imageURL = try await uploadImage()
            let response = try await APIService.shared.createGeneration(
                presetId: preset.id,
                imageURL: imageURL,
                aspectRatio: aspectRatio,
                batchSize: batchSize,
                customPrompt: customPrompt
            )
            await MainActor.run {
                onStarted(response.generationId)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func uploadImage() async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidImage
        }
        if data.count > 10_000_000 {
            throw APIError.fileTooLarge
        }
        let userId = "anonymous"
        return try await StorageService.uploadImage(image, userId: userId)
    }
}
