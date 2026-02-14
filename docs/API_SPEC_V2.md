# Aura API Specification v2.0

> RESTful API для iOS приложения  
> Backend: Hono.js на Supabase Edge Functions

---

## 🌐 Base URLs

```
Production:  https://your-project.supabase.co/functions/v1
Development: http://localhost:54321/functions/v1
```

---

## 🔐 Authentication

Все эндпоинты (кроме `/health`) требуют JWT токен:

```http
Authorization: Bearer <supabase_jwt_token>
```

**Получение токена** (iOS):
```swift
let session = try await supabase.auth.session
let token = session.accessToken
```

---

## 📡 Endpoints

### 1. Health Check

```http
GET /health
```

**Response 200:**
```json
{
  "status": "ok",
  "timestamp": "2026-01-15T10:30:00Z",
  "version": "2.0.0"
}
```

---

### 2. Get Presets

Получить список доступных стилей.

```http
GET /presets
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `mode` | string | No | Filter by mode: `persona`, `object`, `vibe` |
| `page` | integer | No | Page number (default: 1) |
| `limit` | integer | No | Items per page (default: 20) |

**Response 200:**
```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Old Money",
      "slug": "old-money-paris",
      "description": "Эстетика тихого люкса",
      "mode": "persona",
      "icon_url": "https://storage.supabase.co/preset-icons/old-money.webp",
      "is_premium": false,
      "parameters": {
        "guidance_scale": 3.5,
        "num_inference_steps": 28,
        "aspect_ratio": "4:5"
      }
    }
  ],
  "meta": {
    "total": 12,
    "page": 1,
    "limit": 20,
    "has_more": false
  }
}
```

**Error Responses:**

```json
// 401 Unauthorized
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}

// 500 Internal Server Error
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Failed to fetch presets",
    "request_id": "req_abc123xyz"
  }
}
```

**TypeScript Types:**
```typescript
interface Preset {
  id: string;
  name: string;
  slug: string;
  description: string;
  mode: 'persona' | 'object' | 'vibe';
  icon_url: string;
  is_premium: boolean;
  parameters: {
    guidance_scale: number;
    num_inference_steps: number;
    aspect_ratio: string;
  };
}

interface PresetsResponse {
  data: Preset[];
  meta: {
    total: number;
    page: number;
    limit: number;
    has_more: boolean;
  };
}
```

---

### 3. Create Generation

Запустить генерацию изображения.

```http
POST /generations
Content-Type: application/json
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "preset_id": "550e8400-e29b-41d4-a716-446655440000",
  "image_url": "https://storage.supabase.co/uploads/user123/photo.jpg",
  "aspect_ratio": "4:5",
  "batch_size": 4,
  "custom_prompt": "soft natural lighting"
}
```

**Request Schema (Zod):**
```typescript
const CreateGenerationSchema = z.object({
  preset_id: z.string().uuid(),
  image_url: z.string().url(),
  aspect_ratio: z.enum(['1:1', '4:5', '16:9']).optional(),
  batch_size: z.number().int().min(1).max(4).optional(),
  custom_prompt: z.string().max(500).optional(),
});
```

**Response 201:**
```json
{
  "data": {
    "generation_id": "gen_abc123xyz",
    "status": "processing",
    "replicate_ids": ["r8gsdfc92jsd"],
    "estimated_time_seconds": 25,
    "webhook_registered": true,
    "poll_url": "/generations/gen_abc123xyz"
  }
}
```

**Error Responses:**

```json
// 400 Bad Request
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request body",
    "details": [
      {
        "field": "image_url",
        "message": "Must be a valid URL"
      }
    ]
  }
}

// 402 Payment Required
{
  "error": {
    "code": "SUBSCRIPTION_REQUIRED",
    "message": "Active Pro subscription needed for this preset",
    "upgrade_url": "aura://paywall"
  }
}

// 413 Payload Too Large
{
  "error": {
    "code": "FILE_TOO_LARGE",
    "message": "Image exceeds 10MB limit",
    "max_size_mb": 10
  }
}

// 429 Too Many Requests
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Try again later",
    "retry_after_seconds": 60,
    "limit": {
      "requests_per_minute": 10,
      "generations_per_day": 3
    }
  }
}
```

**Backend Logic:**

1. Validate JWT & extract `user_id`
2. Check subscription tier via Supabase:
   ```sql
   SELECT subscription_tier, generations_used_today 
   FROM profiles 
   WHERE id = auth.uid()
   ```
3. Increment `generations_used_today`
4. Upload image to Supabase Storage (if base64)
5. Fetch preset prompt template from `presets` table
6. Call Replicate API:
   ```typescript
   const prediction = await replicate.predictions.create({
     model: getModelForMode(preset.mode),
     input: buildPromptInput(preset, image_url),
     webhook: `${API_URL}/webhooks/replicate`,
     webhook_events_filter: ['completed']
   });
   ```
7. Create record in `generations` table
8. Return `generation_id` for polling

---

### 4. Get Generation Status

Проверить статус генерации (polling endpoint).

```http
GET /generations/:id
Authorization: Bearer <token>
```

**Response 200 (Processing):**
```json
{
  "data": {
    "id": "gen_abc123xyz",
    "status": "processing",
    "progress": 0.65,
    "current_step": "Rendering textures...",
    "created_at": "2026-01-15T10:30:00Z",
    "estimated_completion_at": "2026-01-15T10:30:25Z"
  }
}
```

**Response 200 (Completed):**
```json
{
  "data": {
    "id": "gen_abc123xyz",
    "status": "succeeded",
    "outputs": [
      {
        "id": "asset_001",
        "url": "https://storage.supabase.co/results/gen_abc123xyz_1.jpg",
        "variant": "safe_match",
        "width": 1024,
        "height": 1280
      },
      {
        "id": "asset_002",
        "url": "https://storage.supabase.co/results/gen_abc123xyz_2.jpg",
        "variant": "editorial",
        "width": 1024,
        "height": 1280
      }
    ],
    "metadata": {
      "model_version": "flux-1-dev",
      "seed": 42,
      "actual_time_seconds": 23
    },
    "created_at": "2026-01-15T10:30:00Z",
    "completed_at": "2026-01-15T10:30:23Z"
  }
}
```

**Response 200 (Failed):**
```json
{
  "data": {
    "id": "gen_abc123xyz",
    "status": "failed",
    "error": {
      "code": "NSFW_DETECTED",
      "message": "Content safety check failed"
    },
    "created_at": "2026-01-15T10:30:00Z",
    "failed_at": "2026-01-15T10:30:15Z"
  }
}
```

**Error Responses:**

```json
// 404 Not Found
{
  "error": {
    "code": "GENERATION_NOT_FOUND",
    "message": "Generation with id 'gen_xyz' does not exist"
  }
}

// 403 Forbidden
{
  "error": {
    "code": "FORBIDDEN",
    "message": "You don't have access to this generation"
  }
}
```

**Polling Strategy (iOS):**
```swift
func pollGenerationStatus(id: String) async throws -> GenerationResult {
    var attempts = 0
    let maxAttempts = 60 // 2 minutes max
    
    while attempts < maxAttempts {
        let status = try await apiService.getGeneration(id: id)
        
        switch status.status {
        case "succeeded":
            return status
        case "failed":
            throw GenerationError.failed(status.error)
        case "processing":
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 sec
            attempts += 1
        default:
            break
        }
    }
    
    throw GenerationError.timeout
}
```

---

### 5. Cancel Generation

Отменить генерацию в процессе.

```http
DELETE /generations/:id
Authorization: Bearer <token>
```

**Response 200:**
```json
{
  "data": {
    "id": "gen_abc123xyz",
    "status": "canceled",
    "canceled_at": "2026-01-15T10:30:10Z"
  }
}
```

**Backend Logic:**
1. Update `generations.status = 'canceled'`
2. Call Replicate cancel endpoint:
   ```typescript
   await replicate.predictions.cancel(replicateId);
   ```

---

### 6. Get User Generations (Gallery)

Получить историю генераций пользователя.

```http
GET /generations
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page` | integer | No | Page number (default: 1) |
| `limit` | integer | No | Items per page (default: 20) |
| `preset_id` | string | No | Filter by preset |
| `status` | string | No | Filter by status: `succeeded`, `failed` |

**Response 200:**
```json
{
  "data": [
    {
      "id": "gen_abc123",
      "preset": {
        "id": "preset_001",
        "name": "Old Money",
        "icon_url": "https://..."
      },
      "status": "succeeded",
      "outputs": [
        {
          "url": "https://...",
          "variant": "safe_match",
          "is_favorite": true
        }
      ],
      "created_at": "2026-01-15T10:00:00Z"
    }
  ],
  "meta": {
    "total": 45,
    "page": 1,
    "limit": 20,
    "has_more": true
  }
}
```

---

### 7. Update Generation Asset

Обновить метаданные asset (например, добавить в избранное).

```http
PATCH /generation-assets/:id
Content-Type: application/json
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "is_favorite": true
}
```

**Response 200:**
```json
{
  "data": {
    "id": "asset_001",
    "is_favorite": true,
    "updated_at": "2026-01-15T10:35:00Z"
  }
}
```

---

### 8. Webhook от Replicate (Internal)

Принимает результаты генерации.

```http
POST /webhooks/replicate
Content-Type: application/json
X-Webhook-Secret: <secret>
```

**Request Body (от Replicate):**
```json
{
  "id": "r8gsdfc92jsd",
  "status": "succeeded",
  "output": [
    "https://replicate.delivery/pbxt/abc123.jpg"
  ],
  "metrics": {
    "predict_time": 22.4
  }
}
```

**Security:**
```typescript
// Validate webhook signature
const secret = c.req.header('X-Webhook-Secret');
if (secret !== env.WEBHOOK_SECRET) {
  return c.json({ error: 'Unauthorized' }, 401);
}
```

**Backend Logic:**
1. Find `generation` by `replicate_id`
2. Download images from Replicate URLs
3. Upload to Supabase Storage:
   ```typescript
   const { data } = await supabase.storage
     .from('results')
     .upload(`${userId}/${generationId}_${variant}.jpg`, imageBlob);
   ```
4. Update `generations.status = 'succeeded'`
5. Create records in `generation_assets`

---

## 🔒 Rate Limiting

| Tier | Requests/min | Generations/day |
|------|--------------|-----------------|
| Free | 10 | 3 |
| Pro  | 60 | Unlimited |

**Response Headers:**
```http
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1642284600
```

**Implementation (Upstash):**
```typescript
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'),
});

export async function rateLimitMiddleware(c: Context, next: Next) {
  const userId = c.get('userId');
  const { success, limit, remaining, reset } = await ratelimit.limit(userId);
  
  c.header('X-RateLimit-Limit', limit.toString());
  c.header('X-RateLimit-Remaining', remaining.toString());
  c.header('X-RateLimit-Reset', reset.toString());
  
  if (!success) {
    return c.json({
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests',
        retry_after_seconds: Math.ceil((reset - Date.now()) / 1000),
      }
    }, 429);
  }
  
  await next();
}
```

---

## 📝 Hono.js Implementation Example

```typescript
// src/index.ts
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { prettyJSON } from 'hono/pretty-json';

import { authMiddleware } from './middleware/auth.middleware';
import { errorMiddleware } from './middleware/error.middleware';

import presetsRoutes from './routes/presets';
import generationsRoutes from './routes/generations';
import webhooksRoutes from './routes/webhooks';

const app = new Hono();

// Global middleware
app.use('*', logger());
app.use('*', prettyJSON());
app.use('*', cors({
  origin: ['aura://app', 'capacitor://localhost'],
  credentials: true,
}));

// Health check (no auth)
app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '2.0.0',
  });
});

// Protected routes
app.use('/presets/*', authMiddleware);
app.use('/generations/*', authMiddleware);

app.route('/presets', presetsRoutes);
app.route('/generations', generationsRoutes);
app.route('/webhooks', webhooksRoutes);

// Global error handler
app.onError(errorMiddleware);

export default app;
```

```typescript
// src/routes/generations.ts
import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import type { Context } from 'hono';

const app = new Hono();

const CreateGenerationSchema = z.object({
  preset_id: z.string().uuid(),
  image_url: z.string().url(),
  aspect_ratio: z.enum(['1:1', '4:5', '16:9']).optional(),
  batch_size: z.number().int().min(1).max(4).optional().default(4),
});

app.post('/', zValidator('json', CreateGenerationSchema), async (c: Context) => {
  const userId = c.get('userId');
  const body = c.req.valid('json');
  
  // Check subscription & limits
  const profile = await getProfile(userId);
  if (!canGenerate(profile)) {
    return c.json({
      error: {
        code: 'LIMIT_EXCEEDED',
        message: 'Daily limit reached',
        upgrade_url: 'aura://paywall'
      }
    }, 402);
  }
  
  // Fetch preset
  const preset = await getPreset(body.preset_id);
  
  // Call Replicate
  const prediction = await createPrediction(preset, body.image_url);
  
  // Save to DB
  const generation = await createGeneration({
    userId,
    presetId: body.preset_id,
    replicateId: prediction.id,
    status: 'processing',
  });
  
  return c.json({
    data: {
      generation_id: generation.id,
      status: 'processing',
      replicate_ids: [prediction.id],
      estimated_time_seconds: 25,
      poll_url: `/generations/${generation.id}`
    }
  }, 201);
});

app.get('/:id', async (c: Context) => {
  const userId = c.get('userId');
  const generationId = c.req.param('id');
  
  const generation = await getGeneration(generationId);
  
  // Check ownership
  if (generation.user_id !== userId) {
    return c.json({ error: { code: 'FORBIDDEN' }}, 403);
  }
  
  return c.json({ data: generation });
});

export default app;
```

---

## 📝 Swift APIService Example

```swift
// Core/Network/APIService.swift
import Foundation

final class APIService {
    static let shared = APIService()
    
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    
    private init() {
        self.baseURL = AppEnvironment.apiBaseURL
        self.session = URLSession.shared
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Presets
    
    func fetchPresets(mode: String? = nil) async throws -> [Preset] {
        var components = URLComponents(url: baseURL.appendingPathComponent("presets"), resolvingAgainstBaseURL: true)!
        if let mode {
            components.queryItems = [URLQueryItem(name: "mode", value: mode)]
        }
        
        let response: PresetsResponse = try await request(url: components.url!)
        return response.data
    }
    
    // MARK: - Generations
    
    func createGeneration(presetId: String, image: UIImage) async throws -> GenerationResponse {
        // 1. Upload image to Supabase Storage
        let imageURL = try await uploadImage(image)
        
        // 2. Create generation
        let body = CreateGenerationRequest(
            preset_id: presetId,
            image_url: imageURL.absoluteString,
            batch_size: 4
        )
        
        let url = baseURL.appendingPathComponent("generations")
        return try await request(url: url, method: "POST", body: body)
    }
    
    func getGeneration(id: String) async throws -> GenerationStatusResponse {
        let url = baseURL.appendingPathComponent("generations/\(id)")
        return try await request(url: url)
    }
    
    // MARK: - Private Helpers
    
    private func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: (some Encodable)? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(errorResponse?.error.message ?? "Unknown error")
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func uploadImage(_ image: UIImage) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidImage
        }
        
        guard data.count <= 10_000_000 else {
            throw APIError.fileTooLarge
        }
        
        // Upload to Supabase Storage
        let fileName = "\(UUID().uuidString).jpg"
        let path = "uploads/\(fileName)"
        
        let uploadData = try await supabase.storage
            .from("uploads")
            .upload(path: path, file: data, options: .init(contentType: "image/jpeg"))
        
        let publicURL = try await supabase.storage
            .from("uploads")
            .getPublicURL(path: path)
        
        return publicURL
    }
}

// MARK: - Models

struct PresetsResponse: Decodable {
    let data: [Preset]
}

struct CreateGenerationRequest: Encodable {
    let preset_id: String
    let image_url: String
    let batch_size: Int
}

struct GenerationResponse: Decodable {
    let data: GenerationData
    
    struct GenerationData: Decodable {
        let generation_id: String
        let status: String
        let estimated_time_seconds: Int
    }
}

struct GenerationStatusResponse: Decodable {
    let data: GenerationStatus
}

struct GenerationStatus: Decodable {
    let id: String
    let status: String
    let outputs: [GenerationOutput]?
    let error: ErrorDetails?
    
    struct ErrorDetails: Decodable {
        let code: String
        let message: String
    }
}

struct ErrorResponse: Decodable {
    let error: APIErrorDetails
    
    struct APIErrorDetails: Decodable {
        let code: String
        let message: String
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case invalidImage
    case fileTooLarge
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Не удалось получить ответ от сервера"
        case .invalidImage:
            return "Не удалось обработать изображение"
        case .fileTooLarge:
            return "Файл слишком большой (макс. 10MB)"
        case .serverError(let message):
            return message
        }
    }
}
```

---

## 📝 Инструкции для Cursor

```
При создании API endpoint:
1. Используй Zod для validation request body
2. Проверяй JWT через authMiddleware
3. Обрабатывай все ошибки (400, 401, 402, 429, 500)
4. Логируй ошибки с request_id
5. Типизируй responses через TypeScript interfaces
6. Добавляй rate limiting на мутации (POST/PATCH/DELETE)

При создании Swift API client:
1. Используй async/await (не completion handlers)
2. Типизируй все responses через Codable
3. Обрабатывай HTTP статусы (switch по statusCode)
4. Добавляй retry логику для network errors
5. Все ошибки конвертируй в LocalizedError
```

---

**Статус:** Production Ready ✅  
**OpenAPI Schema:** Coming soon
