import Foundation

/// Менеджер авторизации. Интегрируй Supabase Auth для получения JWT.
/// APIService.shared.setAuthToken(AuthManager.shared.token)
@Observable
final class AuthManager {
    static let shared = AuthManager()

    var token: String? {
        UserDefaults.standard.string(forKey: "authToken")
    }

    var isAuthenticated: Bool { token != nil }

    func setToken(_ token: String?) {
        UserDefaults.standard.set(token, forKey: "authToken")
        APIService.shared.setAuthToken(token)
    }

    func signOut() {
        setToken(nil)
    }
}
