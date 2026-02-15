import SwiftUI

struct AuthView: View {
    let onAuthenticated: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.auraAccent)
            Text("Войдите в аккаунт")
                .font(.auraTitle)
                .foregroundStyle(.auraTextPrimary)
            Text("Необходима авторизация для генерации фото")
                .font(.auraBody)
                .foregroundStyle(.auraTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: Spacing.md) {
                Button("Sign in with Apple (скоро)") {
                    // TODO: Supabase Auth - signInWithIdToken(credentials: .apple(idToken:))
                }
                .font(.auraHeadline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(CornerRadius.button)
                Text("Добавь Supabase Auth для входа")
                    .font(.auraCaption)
                    .foregroundStyle(.auraTextSecondary)
                #if DEBUG
                Button("Skip (только UI, API вернёт 401)") {
                    AuthManager.shared.setToken("dev-skip")
                    onAuthenticated()
                }
                .font(.auraCaption)
                .foregroundStyle(.auraTextSecondary)
                #endif
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(Color.auraBackground)
    }
}
