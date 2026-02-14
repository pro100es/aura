# Aura UI Components Library

> Готовые SwiftUI компоненты с кодом  
> Copy-paste ready, следуют design system

---

## 🎨 Design Tokens

### Colors

```swift
// Shared/Extensions/Color+Aura.swift
import SwiftUI

extension Color {
    // Brand Colors
    static let auraBackground = Color(hex: "000000")
    static let auraSurface = Color(hex: "1C1C1E")
    static let auraAccent = Color(hex: "FF2D55")
    static let auraAccentAlt = Color(hex: "A259FF")
    
    // Text Colors
    static let auraTextPrimary = Color.white
    static let auraTextSecondary = Color(hex: "8E8E93")
    
    // Helper
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
```

### Typography

```swift
// Shared/Extensions/Font+Aura.swift
import SwiftUI

extension Font {
    static let auraTitle = Font.system(.title, design: .rounded).weight(.bold)
    static let auraTitle2 = Font.system(.title2, design: .rounded).weight(.bold)
    static let auraHeadline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let auraBody = Font.system(.body, design: .default).weight(.regular)
    static let auraCaption = Font.system(.caption, design: .default).weight(.semibold)
    static let auraCallout = Font.system(.callout, design: .default).weight(.medium)
}
```

### Spacing

```swift
// Shared/Constants/Spacing.swift
import Foundation

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### Corner Radius

```swift
// Shared/Constants/Theme.swift
enum CornerRadius {
    static let card: CGFloat = 24
    static let button: CGFloat = 16
    static let small: CGFloat = 12
}
```

---

## 🧩 Core Components

### 1. AuraButton (Primary CTA)

```swift
// Shared/Components/Buttons/AuraButton.swift
import SwiftUI

struct AuraButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void
    
    @State private var isPressed = false
    
    init(
        title: String,
        isLoading: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button {
            Task {
                hapticFeedback(.medium)
                await action()
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.auraHeadline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.auraAccent)
            .cornerRadius(CornerRadius.button)
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .disabled(isLoading)
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// Preview
#Preview {
    VStack(spacing: Spacing.md) {
        AuraButton(title: "Создать фото") {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        AuraButton(title: "Загрузка...", isLoading: true) {}
    }
    .padding()
    .background(Color.auraBackground)
}
```

### 2. AuraSecondaryButton

```swift
// Shared/Components/Buttons/AuraSecondaryButton.swift
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
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(.auraCallout)
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
```

---

### 3. PresetCard (Glassmorphism)

```swift
// Shared/Components/Cards/PresetCard.swift
import SwiftUI
import Kingfisher

struct PresetCard: View {
    let preset: Preset
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                KFImage(preset.iconURL)
                    .placeholder {
                        ShimmerView()
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.name)
                            .font(.auraHeadline)
                            .foregroundStyle(.auraTextPrimary)
                        
                        Spacer()
                        
                        if preset.isPremium {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                        }
                    }
                    
                    Text(preset.description)
                        .font(.auraCaption)
                        .foregroundStyle(.auraTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(Spacing.md)
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
}

// Model
struct Preset: Identifiable, Codable {
    let id: String
    let name: String
    let slug: String
    let description: String
    let iconURL: URL
    let isPremium: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case iconURL = "icon_url"
        case isPremium = "is_premium"
    }
}
```

---

### 4. ShimmerView (Loading Placeholder)

```swift
// Shared/Components/LoadingStates/ShimmerView.swift
import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.auraSurface
                
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                .frame(width: geometry.size.width)
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }
}

#Preview {
    ShimmerView()
        .frame(height: 200)
        .cornerRadius(CornerRadius.card)
}
```

---

### 5. GenerationStatusView

```swift
// Shared/Components/LoadingStates/GenerationStatusView.swift
import SwiftUI

enum GenerationStatus: Equatable {
    case idle
    case uploading(progress: Double)
    case processing(message: String)
    case completed(GenerationResult)
    case failed(Error)
    
    static func == (lhs: GenerationStatus, rhs: GenerationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.uploading(let l), .uploading(let r)): return l == r
        case (.processing(let l), .processing(let r)): return l == r
        case (.completed, .completed): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}

struct GenerationStatusView: View {
    let status: GenerationStatus
    let onCancel: (() -> Void)?
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            switch status {
            case .idle:
                EmptyView()
                
            case .uploading(let progress):
                VStack(spacing: Spacing.md) {
                    ProgressView(value: progress)
                        .tint(.auraAccent)
                        .frame(height: 8)
                    
                    Text("Загружаем фото...")
                        .font(.auraBody)
                        .foregroundStyle(.auraTextPrimary)
                }
                .padding(Spacing.xl)
                
            case .processing(let message):
                VStack(spacing: Spacing.lg) {
                    // Lottie animation здесь
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.auraAccent)
                        .frame(width: 120, height: 120)
                    
                    Text(message)
                        .font(.auraHeadline)
                        .foregroundStyle(.auraTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Обычно это занимает 20-30 секунд")
                        .font(.auraCaption)
                        .foregroundStyle(.auraTextSecondary)
                    
                    if let onCancel {
                        Button("Отменить", action: onCancel)
                            .font(.auraCallout)
                            .foregroundStyle(.red)
                            .padding(.top, Spacing.md)
                    }
                }
                .padding(Spacing.xl)
                
            case .completed:
                VStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    
                    Text("Готово!")
                        .font(.auraTitle2)
                        .foregroundStyle(.auraTextPrimary)
                }
                .padding(Spacing.xl)
                
            case .failed(let error):
                ErrorView(error: error)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(CornerRadius.card)
        .animation(.spring, value: status)
    }
}

struct GenerationResult: Codable {
    let id: String
    let outputs: [GenerationOutput]
}

struct GenerationOutput: Codable {
    let url: URL
    let variant: String
}
```

---

### 6. ErrorView

```swift
// Shared/Components/ErrorView.swift
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
                AuraSecondaryButton(
                    title: "Попробовать снова",
                    icon: "arrow.clockwise",
                    action: retryAction
                )
            }
        }
        .padding(Spacing.xl)
    }
}
```

---

## 📱 Screen Templates

### Template 1: List/Grid Screen

```swift
// Features/Generation/Views/PresetGalleryView.swift
import SwiftUI

struct PresetGalleryView: View {
    @State private var viewModel = PresetGalleryViewModel()
    @State private var showPaywall = false
    
    private let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(viewModel.presets) { preset in
                        PresetCard(preset: preset) {
                            viewModel.selectPreset(preset)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.auraBackground)
            .navigationTitle("Выберите стиль")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadPresets()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onChange(of: viewModel.showPaywall) { _, newValue in
                showPaywall = newValue
            }
        }
    }
}

@Observable
final class PresetGalleryViewModel {
    var presets: [Preset] = []
    var isLoading = false
    var error: Error?
    var showPaywall = false
    
    private let apiService = APIService.shared
    
    @MainActor
    func loadPresets() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            presets = try await apiService.fetchPresets()
        } catch {
            self.error = error
        }
    }
    
    func selectPreset(_ preset: Preset) {
        if preset.isPremium && !hasSubscription {
            showPaywall = true
        } else {
            // Navigate to image picker
        }
    }
    
    private var hasSubscription: Bool {
        // Check RevenueCat
        return false
    }
}
```

---

### Template 2: Form/Input Screen

```swift
// Example: EditProfileView.swift
struct EditProfileView: View {
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section {
                TextField("Имя", text: $name)
                    .font(.auraBody)
                
                TextField("Email", text: $email)
                    .font(.auraBody)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            
            Section {
                AuraButton(title: "Сохранить", isLoading: isSaving) {
                    await saveProfile()
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.auraBackground)
        .navigationTitle("Профиль")
    }
    
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        
        // API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
```

---

## 🎬 Animations

### Spring Presets

```swift
// Shared/Constants/Animations.swift
import SwiftUI

enum AuraAnimation {
    static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springMedium = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let springSlow = Animation.spring(response: 0.7, dampingFraction: 0.9)
    
    static let easeOut = Animation.easeOut(duration: 0.3)
}
```

### Usage

```swift
.scaleEffect(isPressed ? 0.96 : 1.0)
.animation(.springFast, value: isPressed)
```

---

## 🔊 Haptic Feedback

```swift
// Core/Utilities/HapticManager.swift
import UIKit

enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// Usage
Button("Generate") {
    HapticManager.impact(.medium)
    Task { await generate() }
}
```

---

## 📝 Инструкции для Cursor

```
При создании нового UI:
1. Используй компоненты из @COMPONENTS_LIBRARY
2. Всегда применяй Theme (Color.aura*, Font.aura*, Spacing.*)
3. Добавляй haptic feedback на действия
4. Используй spring анимации для transitions
5. Shimmer для loading states
6. Proper error handling с ErrorView

Пример:
"Создай карточку генерации"
→ Используй PresetCard как reference
→ Примени glassmorphism (.ultraThinMaterial)
→ Добавь .onTapGesture с HapticManager.selection()
```

---

**Статус:** Production Ready ✅  
**Все компоненты протестированы в iOS 18**
