# Aura Project Master Prompt

> **Главный контекстный файл для AI-ассистента (Cursor)**  
> Всегда читай этот документ первым перед выполнением любой задачи

---

## 🎯 Миссия проекта

**Aura** — iOS-приложение для превращения обычных селфи в профессиональные фотографии с помощью AI, сохраняя идентичность лица пользователя.

### Core Value Proposition
- **Input:** Селфи в пижаме на кухне
- **Output:** Профессиональное фото в Париже / Токио / студии Vogue
- **Magic:** Лицо остается на 100% узнаваемым (не маска, а "ты на профессиональной съемке")

---

## 💻 Технологический стек (с версиями)

```yaml
iOS:
  language: Swift 6.1+
  framework: SwiftUI (iOS 18+)
  architecture: MVVM + @Observable
  min_deployment: iOS 18.0
  
  dependencies:
    - Supabase Swift SDK 2.x
    - RevenueCat SDK 4.x
    - Kingfisher 7.x (image caching)

Backend:
  runtime: Bun 1.1+ / Node.js 22+
  framework: Hono.js 4.x
  language: TypeScript 5.3+ (strict mode)
  platform: Supabase Edge Functions
  
  dependencies:
    - @supabase/supabase-js 2.x
    - replicate 0.x (AI SDK)
    - zod 3.x (validation)
    - @upstash/ratelimit (optional)

Database:
  system: PostgreSQL 15+ (Supabase)
  auth: Supabase Auth (Apple Sign-In)
  storage: Supabase Storage (buckets)
  
AI:
  provider: Replicate
  models:
    persona: FLUX.1-dev + InstantID
    object: FLUX.1-dev + ControlNet
    vibe: FLUX.1-dev (img2img)
    
Payments:
  provider: RevenueCat
  platforms: [App Store]
```

---

## 🚨 Критические правила кодирования

### 1. Swift Code Style

```swift
// ✅ ПРАВИЛЬНО: Modern Swift Concurrency
@Observable
final class PhotoGenerationViewModel {
    var status: GenerationStatus = .idle
    var error: Error?
    
    private let apiService: APIService
    
    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }
    
    @MainActor
    func generate(preset: Preset, image: UIImage) async {
        status = .processing(message: "Загружаем фото...")
        
        do {
            let result = try await apiService.createGeneration(
                presetId: preset.id,
                image: image
            )
            status = .completed(result)
        } catch {
            self.error = error
            status = .failed(error)
        }
    }
}

// ❌ НЕПРАВИЛЬНО: Устаревший подход
class OldViewModel: ObservableObject {
    @Published var status: String = ""
    
    func generate(completion: @escaping (Result<Data, Error>) -> Void) {
        // NO! Используй async/await
    }
}
```

### 2. TypeScript Code Style

```typescript
// ✅ ПРАВИЛЬНО: Strict typing + Zod validation
import { z } from 'zod';
import type { Context } from 'hono';

const GenerationRequestSchema = z.object({
  preset_id: z.string().uuid(),
  image_url: z.string().url(),
  aspect_ratio: z.enum(['1:1', '4:5', '16:9']).optional(),
});

type GenerationRequest = z.infer<typeof GenerationRequestSchema>;

export async function createGeneration(c: Context): Promise<Response> {
  const body = await c.req.json();
  const validated = GenerationRequestSchema.parse(body);
  
  const result = await replicateService.predict(validated);
  
  return c.json({ data: result }, 201);
}

// ❌ НЕПРАВИЛЬНО: Any types
async function createGen(c: any) {
  const body: any = await c.req.json(); // NO!
  return c.json(body);
}
```

### 3. Naming Conventions

| Тип | Swift | TypeScript/DB | Пример |
|-----|-------|---------------|--------|
| Variables | `camelCase` | `snake_case` (DB), `camelCase` (TS) | `presetId`, `preset_id` |
| Classes | `PascalCase` | `PascalCase` | `PhotoGenerationViewModel` |
| Files | `PascalCase.swift` | `kebab-case.ts` | `APIService.swift`, `api-service.ts` |
| Constants | `camelCase` | `SCREAMING_SNAKE_CASE` | `defaultTimeout`, `MAX_FILE_SIZE` |

---

## 📁 Структура проекта

```
Aura/
├── AuraApp/                          # iOS приложение
│   ├── App/
│   │   ├── AuraApp.swift            # Entry point
│   │   └── AppEnvironment.swift     # Config + DI
│   │
│   ├── Core/
│   │   ├── Network/
│   │   │   ├── APIService.swift
│   │   │   ├── APIEndpoints.swift
│   │   │   └── NetworkError.swift
│   │   ├── Database/
│   │   │   └── SupabaseClient.swift
│   │   └── Utilities/
│   │       ├── ImageProcessor.swift
│   │       └── HapticManager.swift
│   │
│   ├── Features/
│   │   ├── Onboarding/
│   │   │   ├── Views/
│   │   │   │   ├── OnboardingIntroView.swift
│   │   │   │   ├── ModeSelectionView.swift
│   │   │   │   └── PaywallView.swift
│   │   │   └── ViewModels/
│   │   │       └── OnboardingViewModel.swift
│   │   │
│   │   ├── Generation/
│   │   │   ├── Views/
│   │   │   │   ├── PresetGalleryView.swift
│   │   │   │   ├── ImagePickerView.swift
│   │   │   │   ├── GenerationProcessView.swift
│   │   │   │   └── ResultsCarouselView.swift
│   │   │   └── ViewModels/
│   │   │       └── GenerationViewModel.swift
│   │   │
│   │   ├── Gallery/
│   │   │   ├── Views/
│   │   │   │   └── GalleryView.swift
│   │   │   └── ViewModels/
│   │   │       └── GalleryViewModel.swift
│   │   │
│   │   └── Profile/
│   │       └── Views/
│   │           └── ProfileView.swift
│   │
│   ├── Shared/
│   │   ├── Components/
│   │   │   ├── Buttons/
│   │   │   │   └── AuraButton.swift
│   │   │   ├── Cards/
│   │   │   │   └── PresetCard.swift
│   │   │   └── LoadingStates/
│   │   │       └── ShimmerView.swift
│   │   │
│   │   ├── Extensions/
│   │   │   ├── Color+Aura.swift
│   │   │   ├── Font+Aura.swift
│   │   │   └── View+Extensions.swift
│   │   │
│   │   └── Constants/
│   │       ├── Theme.swift
│   │       ├── Spacing.swift
│   │       └── Strings.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Config.xcconfig           # Environment vars
│       └── Info.plist
│
├── backend/                          # Hono.js API
│   ├── src/
│   │   ├── routes/
│   │   │   ├── presets.ts
│   │   │   ├── generations.ts
│   │   │   └── webhooks.ts
│   │   │
│   │   ├── services/
│   │   │   ├── replicate.service.ts
│   │   │   ├── supabase.service.ts
│   │   │   └── prompts.service.ts
│   │   │
│   │   ├── middleware/
│   │   │   ├── auth.middleware.ts
│   │   │   ├── rate-limit.middleware.ts
│   │   │   └── error.middleware.ts
│   │   │
│   │   ├── types/
│   │   │   └── api.types.ts
│   │   │
│   │   ├── config/
│   │   │   └── env.ts
│   │   │
│   │   └── index.ts                 # Hono app entry
│   │
│   ├── supabase/
│   │   ├── migrations/
│   │   │   ├── 20260115000001_initial_schema.sql
│   │   │   └── 20260115000002_functions_triggers.sql
│   │   │
│   │   └── seed.sql
│   │
│   ├── prompts/
│   │   └── presets.json             # AI prompts library
│   │
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
│
└── docs/                             # Документация
    ├── MASTER_PROMPT.md              # 👈 Ты здесь
    ├── API_SPEC_V2.md
    ├── DB_SCHEMA_V2.md
    ├── COMPONENTS_LIBRARY.md
    ├── PROMPTS_ENGINE.md
    ├── USER_STORIES.md
    └── ENVIRONMENT_CONFIG.md
```

---

## ⚡ Быстрые команды для Cursor

### Создать новый экран (SwiftUI)
```
@MASTER_PROMPT создай PresetGalleryView с:
- LazyVGrid 2 колонки
- Async загрузка из API /presets
- ShimmerView placeholders
- @Observable ViewModel
Следуй @COMPONENTS_LIBRARY для стилей
```

### Создать API endpoint (Hono)
```
@MASTER_PROMPT создай POST /generations:
- Zod validation для request body
- JWT auth middleware
- Проверка subscription через Supabase RLS
- Вызов Replicate API
- Webhook registration
Следуй @API_SPEC_V2
```

### Создать DB migration
```
@MASTER_PROMPT создай таблицу presets:
- UUID primary key
- RLS policies для public read
- Indexes на slug и mode
Следуй @DB_SCHEMA_V2
```

---

## 🎨 Design System (Quick Reference)

```swift
// Colors
Color.auraBackground  // #000000
Color.auraSurface     // #1C1C1E
Color.auraAccent      // #FF2D55
Color.auraTextPrimary // #FFFFFF

// Typography
Font.auraTitle        // SF Pro Rounded Bold
Font.auraBody         // SF Pro Regular

// Spacing (8pt grid)
Spacing.xs  = 4pt
Spacing.sm  = 8pt
Spacing.md  = 16pt
Spacing.lg  = 24pt
Spacing.xl  = 32pt

// Corner Radius
24pt для cards
16pt для buttons
```

**Полная спецификация:** `@COMPONENTS_LIBRARY.md`

---

## 🔒 Безопасность и приватность

### Обязательные проверки в коде:

1. **JWT Validation** (каждый API запрос)
```typescript
// middleware/auth.middleware.ts
const token = c.req.header('Authorization')?.replace('Bearer ', '');
const { data: user } = await supabase.auth.getUser(token);
if (!user) throw new UnauthorizedError();
```

2. **File Size Validation** (iOS)
```swift
guard let imageData = image.jpegData(compressionQuality: 0.8),
      imageData.count <= 10_000_000 else {
    throw ValidationError.fileTooLarge
}
```

3. **NSFW Filter** (Replicate)
```typescript
const prediction = await replicate.predictions.create({
  input: {
    ...params,
    safety_checker: true, // ✅ Всегда включено
  }
});
```

4. **RLS Policies** (Supabase)
```sql
-- Пользователь видит только свои данные
CREATE POLICY "Users view own data"
ON generations FOR SELECT
USING (auth.uid() = user_id);
```

---

## 📊 Метрики качества кода

### Перед каждым commit проверяй:

- [ ] ✅ Нет `any` в TypeScript
- [ ] ✅ Нет `completion handlers` в Swift (только `async/await`)
- [ ] ✅ Все `@Observable` классы помечены `final`
- [ ] ✅ Error handling присутствует (try/catch)
- [ ] ✅ UI компоненты используют `Theme` константы
- [ ] ✅ API responses типизированы через `zod`
- [ ] ✅ SQL queries используют параметризацию (no string interpolation)

---

## 🎯 Workflow для фич

### Когда получаешь задачу от пользователя:

1. **Анализ**: Определи к какому Epic/Story относится задача (`@USER_STORIES.md`)
2. **Контракт**: Проверь API spec (`@API_SPEC_V2.md`) и DB schema (`@DB_SCHEMA_V2.md`)
3. **UI**: Используй готовые компоненты (`@COMPONENTS_LIBRARY.md`)
4. **Код**: Пиши следуя patterns из этого документа
5. **Проверка**: Убедись что acceptance criteria выполнены

### Пример:
```
Пользователь: "Добавь экран выбора пресетов"

1. Читаешь @USER_STORIES.md → Story 2.1
2. Читаешь @API_SPEC_V2.md → GET /presets
3. Читаешь @COMPONENTS_LIBRARY.md → PresetCard
4. Создаешь PresetGalleryView.swift + ViewModel
5. Проверяешь acceptance criteria из Story 2.1
```

---

## 📝 Git Commit Convention

```
<type>(<scope>): <subject>

feat(generation): add preset gallery screen
fix(api): handle replicate timeout errors
docs(readme): update installation steps
refactor(ui): extract shimmer to reusable component
```

---

## 🚀 Быстрый старт для нового разработчика

1. Прочитай `MASTER_PROMPT.md` (этот файл)
2. Настрой окружение (`@ENVIRONMENT_CONFIG.md`)
3. Запусти DB migrations (`@DB_SCHEMA_V2.md`)
4. Изучи компоненты (`@COMPONENTS_LIBRARY.md`)
5. Начни с Epic 1 в `@USER_STORIES.md`

---

## 📞 Контекст для Cursor AI

```
Ты — Senior iOS + Backend разработчик, создающий Aura.

Твои принципы:
- Код сразу, объяснения кратко
- Используй только современные API (async/await, @Observable)
- Следуй структуре из @MASTER_PROMPT
- При неясности — уточни, не гадай
- Всегда проверяй типы и обрабатывай ошибки

Твои инструменты:
@MASTER_PROMPT.md      — архитектура
@USER_STORIES.md       — что делать
@API_SPEC_V2.md        — backend контракт
@DB_SCHEMA_V2.md       — структура БД
@COMPONENTS_LIBRARY.md — UI kit
@PROMPTS_ENGINE.md     — AI промпты
```

---

**Версия:** 2.0  
**Последнее обновление:** 2026-01-15  
**Статус:** Production Ready ✅
