import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL: URL
    private let session: URLSession
    var authToken: String?

    private init() {
        self.baseURL = AppEnvironment.apiBaseURL
        self.session = URLSession.shared
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    func fetchPresets(mode: PresetMode? = nil) async throws -> [Preset] {
        var url = baseURL.appendingPathComponent("presets")
        if let mode {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            components.queryItems = [URLQueryItem(name: "mode", value: mode.rawValue)]
            url = components.url!
        }

        let response: PresetsResponse = try await request(url: url)
        return response.data
    }

    func createGeneration(
        presetId: String,
        imageURL: String,
        aspectRatio: String? = "4:5",
        batchSize: Int? = 4,
        customPrompt: String? = nil
    ) async throws -> GenerationData {
        let body = CreateGenerationRequest(
            presetId: presetId,
            imageURL: imageURL,
            aspectRatio: aspectRatio,
            batchSize: batchSize,
            customPrompt: customPrompt
        )
        let url = baseURL.appendingPathComponent("generations")
        let response: CreateGenerationResponse = try await request(url: url, method: "POST", body: body)
        return response.data
    }

    func getGeneration(id: String) async throws -> GenerationStatus {
        let url = baseURL.appendingPathComponent("generations").appendingPathComponent(id)
        let response: GenerationStatusResponse = try await request(url: url)
        return response.data
    }

    func cancelGeneration(id: String) async throws {
        let url = baseURL.appendingPathComponent("generations").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuth(to: &request)
        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError("Failed to cancel")
        }
    }

    private func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: (some Encodable)? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuth(to: &request)

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        if 200 ..< 300 ~= httpResponse.statusCode {
            return try JSONDecoder().decode(T.self, from: data)
        }

        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            throw APIError.serverError(errorResponse.error.message)
        }
        throw APIError.serverError("Unknown error (\(httpResponse.statusCode))")
    }

    private func addAuth(to request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

enum APIError: LocalizedError {
    case unauthorized
    case serverError(String)
    case invalidResponse
    case invalidImage
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Необходима авторизация"
        case .serverError(let msg): return msg
        case .invalidResponse: return "Некорректный ответ сервера"
        case .invalidImage: return "Не удалось обработать изображение"
        case .fileTooLarge: return "Файл слишком большой (макс. 10 МБ)"
        }
    }
}
