import SwiftUI
import PhotosUI

struct ImagePickerView: View {
    let preset: Preset
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showGenerationOptions = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if let image = selectedImage {
                previewSection(image: image)
            } else {
                pickerSection
            }
        }
        .padding(Spacing.lg)
        .background(Color.auraBackground)
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .sheet(isPresented: $showGenerationOptions) {
            if let img = selectedImage {
                GenerationOptionsView(
                    preset: preset,
                    image: img,
                    onStart: { showGenerationOptions = false }
                )
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                selectedImage = image
                showCamera = false
            }
        }
    }

    private var pickerSection: some View {
        VStack(spacing: Spacing.xl) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(.auraAccent)
                    Text("Выбрать из галереи")
                        .font(.auraHeadline)
                        .foregroundStyle(.auraTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.auraSurface)
                .cornerRadius(CornerRadius.card)
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }

            Button {
                showCamera = true
            } label: {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.auraAccent)
                    Text("Сделать фото")
                        .font(.auraHeadline)
                        .foregroundStyle(.auraTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.auraSurface)
                .cornerRadius(CornerRadius.card)
            }
        }
    }

    private func previewSection(image: UIImage) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
                .cornerRadius(CornerRadius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                )

            AuraButton(title: "Создать фото") {
                showGenerationOptions = true
            }

            Button("Выбрать другое") {
                selectedImage = nil
                selectedItem = nil
            }
            .font(.auraCallout)
            .foregroundStyle(.auraTextSecondary)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if data.count > 10_000_000 {
                    await MainActor.run { errorMessage = APIError.fileTooLarge.errorDescription }
                } else {
                    await MainActor.run { selectedImage = image }
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
