# Aura Environment Configuration

## 🔐 Environment Variables

### iOS App (`Config.xcconfig`)

```ini
# Supabase
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# RevenueCat
REVENUECAT_API_KEY_PROD = appl_xxxxxxxxxxxxx
REVENUECAT_API_KEY_DEV = appl_xxxxxxxxxxxxx

# API Base URL
API_BASE_URL_PROD = https://api.aura-app.ai/v1
API_BASE_URL_DEV = http://localhost:8787/v1

# Feature Flags
ENABLE_ANALYTICS = true
ENABLE_CRASH_REPORTING = true
```

**Swift код для доступа:**
```swift
// Core/Config/AppEnvironment.swift
enum AppEnvironment {
    static let supabaseURL = URL(string: Bundle.main.infoDictionary?["SUPABASE_URL"] as! String)!
    static let supabaseKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as! String
    static let revenueCatKey = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as! String
    
    static var apiBaseURL: URL {
        #if DEBUG
        return URL(string: Bundle.main.infoDictionary?["API_BASE_URL_DEV"] as! String)!
        #else
        return URL(string: Bundle.main.infoDictionary?["API_BASE_URL_PROD"] as! String)!
        #endif
    }
}
```

---

### Backend (Hono.js на Supabase Edge Functions)

Создай файл `.env.local` (не коммитить в Git!):

```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Replicate
REPLICATE_API_TOKEN=r8_xxxxxxxxxxxxxxxxxxxx

# Webhooks
WEBHOOK_SECRET=your-secure-random-string

# Rate Limiting (Upstash Redis)
UPSTASH_REDIS_URL=https://your-redis.upstash.io
UPSTASH_REDIS_TOKEN=xxxxxxxxx

# Sentry (optional)
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx
```

**Использование в Hono:**
```typescript
// src/config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string(),
  REPLICATE_API_TOKEN: z.string().startsWith('r8_'),
  WEBHOOK_SECRET: z.string().min(32),
});

export const env = envSchema.parse(process.env);
```

---

## 🚀 Deployment

### iOS (Xcode Cloud / Fastlane)

```ruby
# fastlane/Fastfile
lane :beta do
  increment_build_number
  build_app(scheme: "Aura")
  upload_to_testflight(
    api_key_path: "fastlane/AuthKey.json",
    skip_waiting_for_build_processing: false
  )
end
```

### Backend (Supabase Edge Functions)

```bash
# Deploy edge function
supabase functions deploy generate-image \
  --project-ref your-project-ref \
  --verify-jwt true

# Set secrets
supabase secrets set REPLICATE_API_TOKEN=r8_xxx...
supabase secrets set WEBHOOK_SECRET=your-secret...
```

---

## 📝 Инструкции для Cursor

```
@ENVIRONMENT:
1. Создай Config.xcconfig для iOS с placeholders
2. Создай .env.example для бэкенда
3. Используй zod для валидации environment variables
4. Добавь .env* в .gitignore
5. Документируй где взять каждый ключ (Supabase Dashboard, Replicate, etc)
```
