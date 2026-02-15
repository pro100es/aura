import Foundation
import UIKit

enum StorageService {
    /// Upload image to Supabase Storage, return public URL.
    /// Requires: Supabase SDK, auth session, bucket "uploads" with RLS.
    static func uploadImage(_ image: UIImage, userId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidImage
        }
        if data.count > 10_000_000 {
            throw APIError.fileTooLarge
        }

        // TODO: Integrate Supabase SDK
        // let path = "\(userId)/\(UUID().uuidString).jpg"
        // let supabase = SupabaseManager.shared
        // _ = try await supabase.storage.from("uploads").upload(path, data)
        // return supabase.storage.from("uploads").getPublicURL(path: path).absoluteString
        //
        // Until then, use mock for development with backend that accepts any URL:
        let fileName = "\(userId)/\(UUID().uuidString).jpg"
        return "https://placehold.co/1024x1280/1C1C1E/8E8E93?text=Upload"
    }
}
