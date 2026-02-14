# 🚀 Aura - Быстрый старт (5 минут)

> Пошаговая инструкция для запуска проекта с нуля

---

## Шаг 1: Клонирование (30 сек)

```bash
# Клонируй репозиторий
git clone https://github.com/your-org/aura.git
cd aura

# Запусти автоматическую настройку
./setup.sh
```

**Результат:** Создана вся структура проекта ✅

---

## Шаг 2: Настройка Supabase (2 мин)

### 2.1 Создание проекта
1. Открой [supabase.com](https://supabase.com)
2. Создай новый проект "Aura"
3. Выбери регион (ближайший к тебе)
4. Сохрани пароль БД

### 2.2 Получение ключей
1. Открой Settings → API
2. Копируй:
   - **Project URL** → `https://xxx.supabase.co`
   - **anon public** → `eyJhbG...`
   - **service_role** → `eyJhbG...` ⚠️ Секретный!

### 2.3 Запуск миграций
```bash
cd backend

# Инициализация Supabase CLI
supabase init

# Добавь в supabase/config.toml:
# project_id = "xxx-xxx-xxx"

# Запуск миграций
supabase db push
```

**Результат:** База данных создана с таблицами profiles, presets, generations ✅

---

## Шаг 3: Настройка Replicate (1 мин)

### 3.1 Регистрация
1. Открой [replicate.com](https://replicate.com)
2. Sign up через GitHub
3. Добавь billing (нужен для API)

### 3.2 API Token
1. Открой Account → API Tokens
2. Create token → копируй: `r8_xxxxx...`

**Результат:** API token для AI моделей ✅

---

## Шаг 4: Backend Setup (1 мин)

```bash
cd backend

# Установка зависимостей
bun install

# Создание .env из шаблона
cp .env.example .env

# Редактируй .env (используй свои ключи):
nano .env
```

**Твой `.env` должен выглядеть так:**
```bash
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJI...
REPLICATE_API_TOKEN=r8_xxxxxxxxx
WEBHOOK_SECRET=$(openssl rand -base64 32)
```

**Запуск сервера:**
```bash
bun run dev
```

Открой http://localhost:3000/health - должен вернуть `{"status":"ok"}`

**Результат:** Backend запущен ✅

---

## Шаг 5: iOS App Setup (1 мин)

### 5.1 Создание проекта в Xcode
```bash
# Открой Xcode
open -a Xcode

# В Xcode:
File → New → Project
→ iOS → App
→ Product Name: "Aura"
→ Interface: SwiftUI
→ Language: Swift
→ Сохрани в папку: aura/AuraApp/
```

### 5.2 Настройка Config
1. Создай файл `Config.xcconfig`:
   ```
   Right Click на Aura → New File → Configuration Settings File
   Имя: Config
   ```

2. Добавь в `Config.xcconfig`:
   ```ini
   SUPABASE_URL = https://xxxx.supabase.co
   SUPABASE_ANON_KEY = eyJhbG...
   REVENUECAT_API_KEY = appl_xxx
   ```

3. В Info.plist добавь:
   ```xml
   <key>SUPABASE_URL</key>
   <string>$(SUPABASE_URL)</string>
   ```

### 5.3 Установка зависимостей
```
File → Add Package Dependencies:

1. Supabase Swift:
   https://github.com/supabase/supabase-swift

2. Kingfisher:
   https://github.com/onevcat/Kingfisher

3. RevenueCat:
   https://github.com/RevenueCat/purchases-ios
```

**Запуск:**
```
Cmd + R (или Product → Run)
```

**Результат:** App запущен на симуляторе ✅

---

## ✅ Проверка работоспособности

### Backend Test
```bash
curl http://localhost:3000/health
# Ответ: {"status":"ok","timestamp":"2026-01-15T..."}
```

### Database Test
```bash
supabase db inspect
# Должны быть таблицы: profiles, presets, generations
```

### iOS Test
В симуляторе должен открыться пустой экран с "Hello, World!"

---

## 🎯 Что дальше?

### Начни разработку с Cursor

1. **Открой проект в Cursor:**
   ```bash
   cursor .
   ```

2. **Используй команды с документацией:**
   ```
   @docs/MASTER_PROMPT создай PresetGalleryView
   ```

3. **Следуй User Stories:**
   - Открой `docs/USER_STORIES.md`
   - Начни с Epic 1: Onboarding
   - Используй Acceptance Criteria как чек-лист

### Полезные команды

```bash
# Backend dev server
cd backend && bun run dev

# Database migrations
supabase db push

# iOS build
cd AuraApp && xcodebuild

# Просмотр логов
tail -f backend/logs/app.log
```

---

## 🆘 Troubleshooting

### Ошибка: "Supabase connection refused"
```bash
# Проверь что Supabase проект активен
supabase status

# Перезапусти локальный Supabase
supabase stop && supabase start
```

### Ошибка: "Replicate API unauthorized"
```bash
# Проверь что токен правильно скопирован
echo $REPLICATE_API_TOKEN

# Должен начинаться с r8_
```

### Ошибка в Xcode: "Module not found"
```
1. Product → Clean Build Folder (Cmd+Shift+K)
2. File → Packages → Reset Package Caches
3. Перезапусти Xcode
```

---

## 📚 Дополнительные ресурсы

- [Master Prompt](docs/MASTER_PROMPT.md) - Главный контекст
- [API Documentation](docs/API_SPEC_V2.md) - API эндпоинты
- [Components Library](docs/COMPONENTS_LIBRARY.md) - UI компоненты
- [Compliance](docs/COMPLIANCE.md) - App Store требования

---

**Готов к разработке! 🚀**

При возникновении вопросов:
- Проверь [docs/MASTER_PROMPT.md](docs/MASTER_PROMPT.md)
- Используй Cursor с `@docs/` префиксом
- Пиши в Slack #aura-dev
