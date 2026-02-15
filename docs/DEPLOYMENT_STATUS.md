# Aura — статус деплоя и следующие шаги

> Последнее обновление: 14 февраля 2026

---

## ✅ Что сделано

### 1. Backend (Hono.js + Bun)
- **API** на Railway: `https://aura-production-91c3.up.railway.app`
- Репозиторий: `pro100es/aura`, Root Directory: `backend`
- Роуты: `/health`, `/presets`, `/generations`, `/webhooks/replicate`
- JWT-аутентификация через Supabase
- Интеграция с Replicate (FLUX.1-dev + InstantID)

### 2. Исправление падения (EADDRINUSE)
- **Проблема:** Bun запускал сервер дважды (автостарт + `if (import.meta.main)`), порт 8080 был занят
- **Решение:** Убран ручной `Bun.serve`, используется `export default { fetch, port, hostname: '0.0.0.0' }` для одного процесса
- Результат: деплой стабилен, сервис Online

### 3. База данных (Supabase)
- Миграции применены (`supabase db push`)
- Таблицы: `profiles`, `presets`, `user_uploads`, `generations`, `generation_assets`, `blocked_terms`
- 8 presets в seed
- Storage buckets: `uploads`, `results`, `preset-icons`

### 4. Переменные Railway
| Переменная | Назначение |
|------------|------------|
| `SUPABASE_URL` | Подключение к БД |
| `SUPABASE_SERVICE_ROLE_KEY` | Сервисный ключ Supabase |
| `SUPABASE_ANON_KEY` | Публичный ключ |
| `REPLICATE_API_TOKEN` | API Replicate для генераций |
| `API_URL` | `https://aura-production-91c3.up.railway.app` — для webhook Replicate |
| `WEBHOOK_SECRET` | Проверка подлинности webhook-запросов от Replicate |

### 5. Домен и webhook
- Домен настроен: `aura-production-91c3.up.railway.app`
- Webhook передаётся автоматически при создании prediction в Replicate (ничего вручную в Replicate не настраивается)

---

## 📱 iOS App (в разработке)

Создана структура в `AuraApp/`:
- **Onboarding**: Intro, выбор режима (Persona/Object/Vibe)
- **PresetGalleryView**: сетка пресетов из API
- **ImagePickerView**: галерея + камера, выбор фото
- **GenerationOptionsView**: aspect_ratio, batch_size, custom_prompt
- **GenerationProcessView**: polling, статусы, отмена
- **ResultsCarouselView**: 4 варианта, AI badge, share/save
- **AuthView**: заглушка (Supabase Auth — TODO)
- **StorageService**: заглушка загрузки в Supabase (TODO)

**Следующие шаги для iOS:**
1. Создать проект в Xcode (см. AuraApp/README.md)
2. Добавить Supabase Swift SDK
3. Реализовать StorageService.uploadImage (загрузка в Supabase Storage)
4. Интегрировать Sign in with Apple через Supabase Auth

---

## 🔜 План действий (по приоритету)

### Фаза 1: Подключение iOS к API

1. **Настроить Config.xcconfig**
   ```
   API_BASE_URL_PROD = https://aura-production-91c3.up.railway.app
   ```
   Без `/v1` — бэкенд не использует префикс `/v1`.

2. **E2E-тест генерации**
   - Логин → выбор пресета → загрузка фото → генерация → результат
   - Проверить логи Railway на приход webhook

3. **CORS** — при необходимости добавить production-домены приложения в `backend/src/index.ts`

---

### Фаза 2: iOS MVP (по USER_STORIES)

**Epic 1 — Онбординг**
- [ ] Story 1.1: OnboardingIntroView (визуальный хук, видео/анимация)
- [ ] Story 1.2: ModeSelectionView (выбор persona/object/vibe)

**Epic 2 — Генерация**
- [ ] Story 2.1: PresetGalleryView (LazyVGrid, загрузка из API, paywall для premium)
- [ ] Story 2.2: ImagePickerView (PhotosPicker, камера, валидация 10MB)
- [ ] Story 2.3: GenerationProcessView (статусы, polling, отмена)
- [ ] Story 2.4: ResultsCarouselView (4 варианта, zoom, favorite, share)

**Epic 3 — Монетизация**
- [ ] Story 3.1: PaywallView (RevenueCat, trial)

**Epic 4 — Галерея**
- [ ] Story 4.1: GalleryView (pagination, фильтры, long press actions)

---

### Фаза 3: Compliance (перед App Store)

- [ ] AIBadge на всех сгенерированных фото
- [ ] Валидация промптов (blocked_terms) — backend + iOS
- [ ] Privacy Disclosure в онбординге
- [ ] Delete Account в настройках
- [ ] App Review Notes для Apple

---

### Фаза 4: Production readiness

**Backend**
- [ ] Rate limiting (Upstash — опционально)
- [ ] Sentry
- [ ] Тесты API

**iOS**
- [ ] TestFlight
- [ ] RevenueCat products
- [ ] Privacy Policy URL
- [ ] Screenshots (6.7", 6.5", 5.5")

---

## 🎨 Референсы дизайна

**Да, можно отправлять.** Референсы помогают:
- Обновить цвета, типографику, spacing в Theme
- Привести компоненты к нужному стилю
- Реализовать анимации и паттерны
- Сохранить консистентность с COMPONENTS_LIBRARY

Форматы: скриншоты, Figma links, описание стиля — всё пригодится.

---

## 🔗 Полезные ссылки

| Сервис | URL |
|--------|-----|
| API Health | https://aura-production-91c3.up.railway.app/health |
| Railway Dashboard | railway.app → truthful-growth → aura |
| Supabase | sugglcpwxlphwaqpdfzz |
| Replicate | replicate.com/account |

---

## Быстрая проверка

```bash
# Health
curl https://aura-production-91c3.up.railway.app/health
# Ожидание: {"status":"ok","timestamp":"...","version":"2.0.0"}
```
