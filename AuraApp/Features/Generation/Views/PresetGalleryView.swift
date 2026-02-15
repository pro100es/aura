import SwiftUI

struct PresetGalleryView: View {
    @State private var viewModel = PresetGalleryViewModel()
    @State private var showPaywall = false
    @State private var selectedPreset: Preset?

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else {
                    presetGrid
                }
            }
            .background(Color.auraBackground)
            .navigationTitle("Выберите стиль")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadPresets() }
            .sheet(isPresented: $showPaywall) { PaywallPlaceholderView() }
            .navigationDestination(item: $selectedPreset) { preset in
                ImagePickerView(preset: preset)
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView().tint(.auraAccent).scaleEffect(1.2)
            Spacer()
        }
    }

    private var presetGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(viewModel.presets) { preset in
                    PresetCard(preset: preset) {
                        handlePresetTap(preset)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private func handlePresetTap(_ preset: Preset) {
        if preset.isPremium && !viewModel.hasSubscription {
            showPaywall = true
        } else {
            selectedPreset = preset
            navigateToImagePicker = true
        }
    }
}

@Observable
final class PresetGalleryViewModel {
    var presets: [Preset] = []
    var isLoading = false
    var error: Error?
    var hasSubscription = false

    @MainActor
    func loadPresets() async {
        isLoading = true
        defer { isLoading = false }

        let mode = UserDefaults.standard.string(forKey: "userMode").flatMap(PresetMode.init) ?? .persona
        do {
            presets = try await APIService.shared.fetchPresets(mode: mode)
        } catch {
            self.error = error
        }
    }
}
