import Foundation

enum AppEnvironment {
    static var supabaseURL: URL {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let parsed = URL(string: url) else {
            fatalError("SUPABASE_URL not configured in Info.plist")
        }
        return parsed
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist")
        }
        return key
    }

    static var apiBaseURL: URL {
        #if DEBUG
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_DEV") as? String
            ?? "http://localhost:3000"
        #else
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL_PROD") as? String
            ?? "https://aura-production-91c3.up.railway.app"
        #endif
        guard let url = URL(string: urlString) else {
            fatalError("Invalid API_BASE_URL")
        }
        return url
    }
}
