# Aura - AI Photo Styling App

> Превращаем обычные селфи в профессиональные фотографии с помощью AI

![iOS](https://img.shields.io/badge/iOS-18%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.1-orange)
![TypeScript](https://img.shields.io/badge/TypeScript-5.3-blue)
![License](https://img.shields.io/badge/license-Proprietary-red)

---

## 🎯 Что это?

**Aura** — мобильное приложение для iOS, которое позволяет пользователям создавать профессиональные фотографии из простых селфи, используя технологию InstantID (сохранение лица) + FLUX.1 AI.

### Ключевые возможности:
- ✨ **Готовые стили**: Old Money, Urban Night, Scandi, Editorial
- 🎨 **Сохранение идентичности**: Лицо остается узнаваемым (не deepfake)
- 🚀 **Быстрая генерация**: 20-30 секунд на 4 варианта
- 💎 **Freemium модель**: 3 бесплатные генерации, Pro подписка через RevenueCat

---

## 🏗️ Архитектура

```
┌─────────────────┐
│   iOS App       │ Swift 6.1 + SwiftUI
│   (Frontend)    │
└────────┬────────┘
         │ REST API
         ▼
┌─────────────────┐
│  Hono.js API    │ TypeScript + Bun
│  (Backend)      │
└────────┬────────┘
         │
    ┌────┴─────┐
    │          │
    ▼          ▼
┌────────┐  ┌──────────┐
│Supabase│  │Replicate │
│Auth/DB │  │AI Models │
└────────┘  └──────────┘
```

### Tech Stack
- **Frontend**: SwiftUI, MVVM, @Observable
- **Backend**: Hono.js на Supabase Edge Functions
- **Database**: PostgreSQL (Supabase)
- **AI**: Replicate (FLUX.1-dev + InstantID)
- **Payments**: RevenueCat
- **Storage**: Supabase Storage

---

## 🚀 Быстрый старт

### Требования
- macOS 14+ (Sonoma)
- Xcode 15+
- Node.js 22+ / Bun 1.1+
- Supabase CLI
- Git

### 1. Клонирование репозитория

```bash
git clone https://github.com/your-org/aura.git
cd aura
```

### 2. Настройка Backend

```bash
cd backend

# Установка зависимостей
bun install

# Копирование .env
cp .env.example .env

# Редактируй .env добавь свои ключи:
# - SUPABASE_URL
# - SUPABASE_SERVICE_ROLE_KEY
# - REPLICATE_API_TOKEN

# Запуск миграций БД
supabase db push

# Запуск локального сервера
bun run dev
```

### 3. Настройка iOS App

```bash
cd ../AuraApp

# Открыть в Xcode
open Aura.xcodeproj

# Настрой Config.xcconfig:
# - SUPABASE_URL
# - SUPABASE_ANON_KEY
# - REVENUECAT_API_KEY

# Запусти на симуляторе
# Cmd + R
```

---

## 📁 Структура проекта

```
aura/
├── docs/                    # 📚 Документация
│   ├── MASTER_PROMPT.md     # Главный контекст для Cursor
│   ├── API_SPEC_V2.md       # API спецификация
│   ├── DB_SCHEMA_V2.md      # База данных
│   ├── COMPONENTS_LIBRARY.md# UI компоненты
│   ├── COMPLIANCE.md        # App Store требования
│   └── USER_STORIES.md      # Пользовательские сценарии
│
├── AuraApp/                 # 📱 iOS приложение
│   ├── App/
│   ├── Core/
│   ├── Features/
│   ├── Shared/
│   └── Resources/
│
├── backend/                 # ⚙️ Backend API
│   ├── src/
│   │   ├── routes/
│   │   ├── services/
│   │   └── middleware/
│   ├── supabase/
│   │   └── migrations/
│   └── prompts/
│
└── README.md               # 👈 Ты здесь
```

---

## 📖 Документация

### Для разработчиков
- [🎯 Master Prompt](docs/MASTER_PROMPT.md) - Главный контекст для AI
- [🎨 Components Library](docs/COMPONENTS_LIBRARY.md) - Готовые UI компоненты
- [🔌 API Spec](docs/API_SPEC_V2.md) - Документация API
- [💾 DB Schema](docs/DB_SCHEMA_V2.md) - Структура базы данных

### Для продукта
- [📋 User Stories](docs/USER_STORIES.md) - Пользовательские сценарии
- [✅ Compliance](docs/COMPLIANCE.md) - Требования App Store

---

## 🔑 Настройка Secrets

### Supabase (база данных)
1. Создай проект на [supabase.com](https://supabase.com)
2. Скопируй:
   - `Project URL` → `SUPABASE_URL`
   - `anon public` → `SUPABASE_ANON_KEY`
   - `service_role` → `SUPABASE_SERVICE_ROLE_KEY`

### Replicate (AI модели)
1. Регистрация на [replicate.com](https://replicate.com)
2. Создай API token → `REPLICATE_API_TOKEN`

### RevenueCat (подписки)
1. Создай проект в [revenuecat.com](https://revenuecat.com)
2. Настрой App Store Connect
3. Скопируй API Key → `REVENUECAT_API_KEY`

---

## 🧪 Тестирование

### Backend
```bash
cd backend
bun test
```

### iOS (Unit Tests)
```bash
cd AuraApp
xcodebuild test -scheme Aura -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## 🚀 Deployment

### Backend (Supabase Edge Functions)
```bash
supabase functions deploy
supabase secrets set REPLICATE_API_TOKEN=r8_xxx...
```

### iOS (TestFlight)
```bash
fastlane beta
```

---

## 📝 Roadmap

### MVP (Week 1-4)
- [x] Документация и архитектура
- [ ] Database migrations
- [ ] Backend API (Hono)
- [ ] iOS Onboarding
- [ ] Preset Gallery
- [ ] Photo Generation Flow
- [ ] Paywall

### v1.1 (Week 5-8)
- [ ] Custom prompts
- [ ] Gallery с pagination
- [ ] Favorites
- [ ] Share функционал
- [ ] Analytics

### v2.0 (Future)
- [ ] Object Mode (ControlNet)
- [ ] Batch generation
- [ ] Referral system

---

## 🤝 Contributing

Сейчас проект находится в активной разработке. Вклад принимается только от core team.

### Git Workflow
```bash
# Создай ветку для фичи
git checkout -b feature/preset-gallery

# Commit с conventional format
git commit -m "feat(gallery): add preset selection screen"

# Push и создай PR
git push origin feature/preset-gallery
```

---

## 📄 License

Proprietary. Все права защищены © 2026.

---

## 💬 Support

- **Tech Lead**: @your-name
- **Email**: dev@aura-app.ai
- **Docs**: [Notion Workspace](https://notion.so/aura-team)

---

## 🙏 Credits

- **AI Models**: Replicate (FLUX.1, InstantID)
- **Backend**: Supabase, Hono.js
- **Design**: Inspired by Apple HIG
