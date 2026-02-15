import Foundation

struct Preset: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let mode: PresetMode
    let iconURL: URL?
    let isPremium: Bool
    let parameters: PresetParameters?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, mode, parameters
        case iconURL = "icon_url"
        case isPremium = "is_premium"
    }
}

enum PresetMode: String, Codable, CaseIterable {
    case persona
    case object
    case vibe

    var displayName: String {
        switch self {
        case .persona: return "Селфи"
        case .object: return "Предметы"
        case .vibe: return "Сцены"
        }
    }

    var iconName: String {
        switch self {
        case .persona: return "person.fill"
        case .object: return "cube.fill"
        case .vibe: return "sparkles"
        }
    }
}

struct PresetParameters: Codable, Hashable {
    let guidanceScale: Double?
    let numInferenceSteps: Int?
    let aspectRatio: String?

    enum CodingKeys: String, CodingKey {
        case guidanceScale = "guidance_scale"
        case numInferenceSteps = "num_inference_steps"
        case aspectRatio = "aspect_ratio"
    }
}

struct PresetsResponse: Codable {
    let data: [Preset]
    let meta: PresetsMeta?
}

struct PresetsMeta: Codable {
    let total: Int
    let page: Int
    let limit: Int
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case total, page, limit
        case hasMore = "has_more"
    }
}

struct CreateGenerationRequest: Encodable {
    let presetId: String
    let imageURL: String
    let aspectRatio: String?
    let batchSize: Int?
    let customPrompt: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case presetId = "preset_id"
        case aspectRatio = "aspect_ratio"
        case batchSize = "batch_size"
        case customPrompt = "custom_prompt"
    }
}

struct CreateGenerationResponse: Codable {
    let data: GenerationData
}

struct GenerationData: Codable {
    let generationId: String
    let status: String
    let estimatedTimeSeconds: Int?
    let webhookRegistered: Bool?
    let pollURL: String?

    enum CodingKeys: String, CodingKey {
        case generationId = "generation_id"
        case status
        case estimatedTimeSeconds = "estimated_time_seconds"
        case webhookRegistered = "webhook_registered"
        case pollURL = "poll_url"
    }
}

struct GenerationStatusResponse: Codable {
    let data: GenerationStatus
}

struct GenerationStatus: Codable, Identifiable, Hashable {
    let id: String
    let status: String
    let outputs: [GenerationOutput]?
    let error: GenerationErrorDetails?

    struct GenerationOutput: Codable, Hashable {
        let id: String?
        let url: String?
        let variant: String?
    }

    struct GenerationErrorDetails: Codable, Hashable {
        let code: String?
        let message: String?
    }

    var message: String? { error?.message }
}

struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable {
    let code: String
    let message: String
}
