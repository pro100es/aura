import SwiftUI

struct GalleryView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Галерея")
                    .font(.auraTitle)
                    .foregroundStyle(Color.auraTextPrimary)
                Text("Скоро")
                    .font(.auraBody)
                    .foregroundStyle(Color.auraTextSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.auraBackground)
            .navigationTitle("Мои генерации")
        }
    }
}
