import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Профиль")
                        .font(.auraHeadline)
                        .foregroundStyle(.auraTextPrimary)
                }
                Section("Настройки") {
                    NavigationLink("Галерея") { GalleryView() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.auraBackground)
            .navigationTitle("Профиль")
        }
    }
}
