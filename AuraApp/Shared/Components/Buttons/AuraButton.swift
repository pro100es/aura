import SwiftUI

struct AuraButton: View {
    let title: String
    let isLoading: Bool
    let action: () async -> Void

    @State private var isPressed = false

    init(title: String, isLoading: Bool = false, action: @escaping () async -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            Task {
                HapticManager.impact(.medium)
                await action()
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.auraHeadline).foregroundStyle(.white)
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
}
