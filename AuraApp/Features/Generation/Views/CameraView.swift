import SwiftUI

struct CameraView: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    Spacer()
                }

                Spacer()

                Text("Camera — добавь UI в Xcode")
                    .foregroundStyle(.white)
                    .padding()

                Spacer()

                Button("Захватить фото (заглушка)") {
                    if let image = UIImage(systemName: "person.fill") {
                        onCapture(image)
                    }
                }
                .foregroundStyle(.white)
                .padding(.bottom, 40)
            }
        }
    }
}
