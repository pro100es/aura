import Foundation

enum AppEnvironment {
    /// URL Supabase. Замени на свой проект при необходимости.
    static var supabaseURL: URL {
        (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
            .flatMap { URL(string: $0) }
            ?? URL(string: "https://sugglcpwxlphwaqpdfzz.supabase.co")!
    }

    /// Anon key Supabase. Замени на свой из Dashboard → Settings → API.
    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? "PLACEHOLDER_ADD_YOUR_ANON_KEY"
    }

    /// API backend URL.
    static var apiBaseURL: URL {
        #if DEBUG
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_DEV") as? String
            ?? "http://localhost:3000"
        #else
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_PROD") as? String
            ?? "https://aura-production-91c3.up.railway.app"
        #endif
        return URL(string: urlString) ?? URL(string: "https://aura-production-91c3.up.railway.app")!
    }
}
