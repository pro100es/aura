# 🚀 Aura - Deployment Guide

> Пошаговые инструкции для деплоя в production

---

## 📋 Pre-Deployment Checklist

### Backend
- [ ] Все environment variables добавлены в Supabase Secrets
- [ ] Database migrations применены
- [ ] API тесты пройдены
- [ ] Rate limiting настроен
- [ ] Webhooks URL проверен
- [ ] CORS настроен для production домена

### iOS
- [ ] App Store Connect настроен
- [ ] Certificates и Provisioning Profiles созданы
- [ ] Privacy Policy URL добавлен
- [ ] App Review Notes написаны
- [ ] Screenshots подготовлены (6.7", 6.5", 5.5")
- [ ] RevenueCat products созданы

---

## 🗄️ Database Deployment

### 1. Применение миграций

```bash
# Подключись к production Supabase
supabase link --project-ref your-production-ref

# Проверь текущее состояние
supabase db diff

# Примени миграции
supabase db push

# Проверь успешность
supabase db inspect
```

### 2. Seed данные (только первый раз)

```bash
# Добавь пресеты в БД
supabase db execute --file supabase/seed.sql
```

### 3. Storage Buckets

Создай через Supabase Dashboard:
1. `uploads` (private)
2. `results` (private)
3. `preset-icons` (public)

---

## ⚙️ Backend Deployment (Supabase Edge Functions)

### 1. Deploy функций

```bash
cd backend

# Deploy главной функции
supabase functions deploy api \
  --project-ref your-production-ref \
  --verify-jwt true

# Deploy webhook handler
supabase functions deploy webhooks \
  --project-ref your-production-ref \
  --no-verify-jwt
```

### 2. Настройка Secrets

```bash
# Replicate API
supabase secrets set REPLICATE_API_TOKEN=r8_production_key

# Webhook Secret
supabase secrets set WEBHOOK_SECRET=$(openssl rand -base64 32)

# Upstash Redis (опционально)
supabase secrets set UPSTASH_REDIS_URL=https://...
supabase secrets set UPSTASH_REDIS_TOKEN=...
```

### 3. Проверка деплоя

```bash
# Проверь health endpoint
curl https://your-project.supabase.co/functions/v1/api/health

# Ответ должен быть:
# {"status":"ok","timestamp":"...","version":"2.0.0"}
```

---

## 📱 iOS Deployment

### 1. Настройка Certificates

```bash
# Через Fastlane
fastlane match appstore
```

Или вручную:
1. Apple Developer Portal → Certificates
2. Create → iOS Distribution
3. Download и установи в Keychain

### 2. App Store Connect Setup

#### Создание App
1. Открой [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. My Apps → + → New App
3. Fill:
   - Platform: iOS
   - Name: Aura
   - Primary Language: Russian
   - Bundle ID: `com.yourteam.aura`
   - SKU: `AURA-001`

#### App Information
- **Category**: Photo & Video
- **Subcategory**: Photo Editing
- **Content Rights**: Include "AI-Generated Content"
- **Age Rating**: 12+ (содержит AI генерацию)

#### Privacy Policy
- URL: `https://aura-app.ai/privacy`
- (Создай статический сайт на Vercel/Netlify)

### 3. RevenueCat Configuration

```bash
# iOS App-Specific Shared Secret
# (App Store Connect → My Apps → Aura → App Information)

# Добавь в RevenueCat Dashboard:
# Products:
# - aura_pro_monthly: $9.99/month
# - aura_pro_annual: $79.99/year (save 33%)

# Entitlements:
# - pro_access
```

### 4. Build для TestFlight

#### Manual (Xcode)
```
1. Product → Scheme → Edit Scheme
2. Run → Build Configuration → Release
3. Product → Archive
4. Distribute App → App Store Connect
5. Upload
```

#### Automated (Fastlane)
```bash
# Установка Fastlane
brew install fastlane

# Инициализация
cd AuraApp
fastlane init

# fastlane/Fastfile
lane :beta do
  increment_build_number(xcodeproj: "Aura.xcodeproj")
  build_app(scheme: "Aura")
  upload_to_testflight(
    api_key_path: "fastlane/AuthKey.json",
    skip_waiting_for_build_processing: true
  )
  slack(
    message: "New TestFlight build deployed! 🚀",
    slack_url: ENV["SLACK_WEBHOOK"]
  )
end

# Deploy
fastlane beta
```

### 5. App Review Notes

**Скопируй в App Store Connect:**

```
IMPORTANT NOTES FOR APPLE REVIEW:

This is an AI photo styling application (NOT a deepfake app).

TECHNOLOGY:
- Uses InstantID + FLUX.1 models to preserve user's facial identity
- Changes background and clothing only, NOT the face itself
- All AI-generated images are labeled with "✨ AI" badge
- EXIF metadata includes "Software: Aura AI Generator"

CONTENT SAFETY:
- Prompts validated against blocklist (celebrities, NSFW, violence)
- Replicate's safety_checker enabled by default
- Users cannot generate content with famous people

PRIVACY:
- Source images auto-deleted after 24 hours
- Users can delete all data via Settings → Privacy
- Privacy Policy: https://aura-app.ai/privacy

TEST ACCOUNT:
Email: reviewer@aura-app.ai
Password: AppleReview2026!

TEST FLOW:
1. Open app → Skip onboarding
2. Upload a selfie
3. Select "Old Money" preset
4. Wait 25 seconds for generation
5. View 4 AI variants
6. Check AI badge on each image
7. Try typing "Trump" in custom prompt → should be blocked
8. Settings → Privacy → Delete Account → confirm it works

Please test this thoroughly. Thank you! 🙏
```

---

## 🔄 CI/CD Setup (GitHub Actions)

### `.github/workflows/ios-build.yml`

```yaml
name: iOS Build & Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-14
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.2'
      
      - name: Install dependencies
        run: |
          cd AuraApp
          xcodebuild -resolvePackageDependencies
      
      - name: Build
        run: |
          cd AuraApp
          xcodebuild \
            -scheme Aura \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            clean build
      
      - name: Run tests
        run: |
          cd AuraApp
          xcodebuild test \
            -scheme Aura \
            -destination 'platform=iOS Simulator,name=iPhone 15'
      
      - name: Deploy to TestFlight
        if: github.ref == 'refs/heads/main'
        env:
          FASTLANE_USER: ${{ secrets.FASTLANE_USER }}
          FASTLANE_PASSWORD: ${{ secrets.FASTLANE_PASSWORD }}
        run: |
          cd AuraApp
          fastlane beta
```

### `.github/workflows/backend-deploy.yml`

```yaml
name: Backend Deploy

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Bun
        uses: oven-sh/setup-bun@v1
      
      - name: Install dependencies
        run: |
          cd backend
          bun install
      
      - name: Run tests
        run: |
          cd backend
          bun test
      
      - name: Deploy to Supabase
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_PROJECT_REF: ${{ secrets.SUPABASE_PROJECT_REF }}
        run: |
          npx supabase functions deploy \
            --project-ref $SUPABASE_PROJECT_REF
      
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "Backend deployed to production ✅"
            }
```

---

## 📊 Monitoring Setup

### Sentry (Error Tracking)

```bash
# iOS
# Add to Package Dependencies:
https://github.com/getsentry/sentry-cocoa

# In AuraApp.swift:
import Sentry

@main
struct AuraApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://xxx@sentry.io/xxx"
            options.environment = "production"
            options.tracesSampleRate = 1.0
        }
    }
}
```

### Supabase Analytics

```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Query для мониторинга медленных запросов
SELECT 
  query,
  calls,
  total_exec_time,
  mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## 🔒 Security Checklist

- [ ] Environment variables не в репозитории
- [ ] API keys rotated (не dev ключи в prod)
- [ ] RLS policies включены на всех таблицах
- [ ] HTTPS только (no HTTP)
- [ ] Rate limiting настроен
- [ ] Webhook secrets используются
- [ ] User data encryption at rest
- [ ] Backup policy настроен (Supabase Dashboard)

---

## 📈 Post-Deployment

### 1. Проверка работоспособности

```bash
# Backend health
curl https://prod-api-url/health

# Database connection
psql $DATABASE_URL -c "SELECT COUNT(*) FROM profiles;"

# Storage buckets
supabase storage list
```

### 2. Мониторинг

- Dashboard: [app.supabase.co/project/your-ref](https://app.supabase.co)
- Logs: Supabase → Logs
- Analytics: App Store Connect → Analytics
- Revenue: RevenueCat Dashboard

### 3. Rollback Plan

```bash
# Backend rollback
supabase functions delete api
supabase functions deploy api --version previous

# Database rollback
supabase db reset
supabase db push --file migrations/backup_20260115.sql

# iOS - submit previous build from TestFlight
```

---

**Deployment Complete! 🎉**

Monitor первые 24 часа и проверяй:
- Error rates в Sentry
- Response times в Supabase
- Crash reports в App Store Connect
