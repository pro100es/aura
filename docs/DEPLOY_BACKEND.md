# Развёртывание Aura Backend

Пошаговая инструкция для Railway (рекомендуется) или Render.

---

## Перед началом

Если проект ещё не в Git:

```bash
cd "C:\Users\ThinkPad\my projects\aura"
git init
git add .
git commit -m "Initial commit"
# Создай репозиторий на GitHub, затем:
git remote add origin https://github.com/твой-username/aura.git
git branch -M main
git push -u origin main
```

---

## Вариант 1: Railway (рекомендуется)

### 1. Подготовка

1. Зарегистрируйся на [railway.app](https://railway.app)
2. Убедись что проект в Git (GitHub/GitLab)

### 2. Создание проекта

1. **New Project** → **Deploy from GitHub repo**
2. Выбери репозиторий и подключи
3. **Root Directory**: укажи `backend`
4. Railway автоматически определит Bun/Dockerfile

### 3. Переменные окружения

В Railway → проект → **Variables** добавь:

| Переменная | Значение | Откуда |
|------------|----------|--------|
| `SUPABASE_URL` | `https://sugglcpwxlphwaqpdfzz.supabase.co` | Supabase Dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` | Supabase → API → service_role |
| `SUPABASE_ANON_KEY` | `eyJ...` | Supabase → API → anon |
| `REPLICATE_API_TOKEN` | `r8_...` | replicate.com/account |
| `WEBHOOK_SECRET` | случайная строка 32+ символов | придумай сам |

**Важно:** `API_URL` Railway задаёт сам — после деплоя скопируй URL сервиса (например `https://aura-backend-production.up.railway.app`) и добавь:

| Переменная | Значение |
|------------|----------|
| `API_URL` | `https://твой-сервис.up.railway.app` |

### 4. Деплой

Railway деплоит при каждом push в ветку. Или **Deploy** вручную.

### 5. Проверка

```bash
curl https://твой-сервис.up.railway.app/health
# Ответ: {"status":"ok","version":"2.0.0"}
```

---

## Вариант 2: Render

1. [render.com](https://render.com) → **New** → **Web Service**
2. Подключи GitHub, выбери репозиторий
3. **Root Directory**: `backend`
4. **Runtime**: Docker
5. **Dockerfile Path**: `backend/Dockerfile`
6. Добавь переменные в **Environment**
7. Деплой

`RENDER_EXTERNAL_URL` Render задаёт сам — используй его как `API_URL` для webhook.

---

## Вариант 3: Fly.io

```bash
cd backend
fly launch --no-deploy
fly secrets set SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... REPLICATE_API_TOKEN=... WEBHOOK_SECRET=...
fly deploy
```

Добавь `API_URL` = `https://твой-приложение.fly.dev`

---

## После деплоя

1. **API_URL** — нужен для Replicate webhook. Без него статус придётся проверять через polling.
2. **CORS** — уже настроен для `aura://app`, `capacitor://localhost` и localhost.
3. Для production iOS добавь домен в CORS в `backend/src/index.ts` при необходимости.
