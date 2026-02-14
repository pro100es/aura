#!/bin/bash

# Aura Project Setup Script
# Автоматическое создание структуры проекта

set -e  # Exit on error

echo "🚀 Настройка проекта Aura..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода ошибок
error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Функция для успешных сообщений
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Функция для предупреждений
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Проверка зависимостей
echo "Проверка зависимостей..."

command -v git >/dev/null 2>&1 || error "Git не установлен"
command -v node >/dev/null 2>&1 || warning "Node.js не установлен (рекомендуется 22+)"
command -v bun >/dev/null 2>&1 || warning "Bun не установлен (fallback на npm)"

success "Зависимости проверены"

# Создание структуры папок
echo ""
echo "📁 Создание структуры проекта..."

# Docs
mkdir -p docs
success "Создана папка docs/"

# Backend
mkdir -p backend/{src/{routes,services,middleware,types,config},supabase/migrations,prompts}
touch backend/.env.example
success "Создана структура backend/"

# iOS App (будет создано через Xcode, но создаем базовые папки)
mkdir -p AuraApp/{App,Core/{Network,Database,Utilities},Features/{Onboarding,Generation,Gallery,Profile}/{Views,ViewModels},Shared/{Components/{Buttons,Cards,LoadingStates},Extensions,Constants},Resources}
success "Создана структура iOS app/"

# Создание .gitignore
cat > .gitignore << 'EOF'
# Xcode
*.xcworkspace
*.xcuserstate
DerivedData/
.build/
*.ipa
*.dSYM.zip

# Swift Package Manager
.swiftpm/
Package.resolved

# Node / Bun
node_modules/
.env
.env.local
*.log
dist/

# Supabase
.supabase/

# IDE
.vscode/
.idea/
*.swp

# macOS
.DS_Store
Thumbs.db

# Secrets
*.pem
*.key
Config.xcconfig
EOF
success "Создан .gitignore"

# Создание backend package.json
cat > backend/package.json << 'EOF'
{
  "name": "aura-backend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run --watch src/index.ts",
    "build": "bun build src/index.ts --outdir dist",
    "test": "bun test",
    "migrate": "supabase db push"
  },
  "dependencies": {
    "hono": "^4.0.0",
    "@supabase/supabase-js": "^2.39.0",
    "replicate": "^0.25.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.3.0"
  }
}
EOF
success "Создан backend/package.json"

# Создание .env.example
cat > backend/.env.example << 'EOF'
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Replicate AI
REPLICATE_API_TOKEN=r8_your_token_here

# Security
WEBHOOK_SECRET=your-random-secret-min-32-chars

# Optional: Rate Limiting
UPSTASH_REDIS_URL=
UPSTASH_REDIS_TOKEN=
EOF
success "Создан backend/.env.example"

# Создание базового Hono сервера
mkdir -p backend/src
cat > backend/src/index.ts << 'EOF'
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';

const app = new Hono();

// Middleware
app.use('*', logger());
app.use('*', cors());

// Health check
app.get('/health', (c) => {
  return c.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString() 
  });
});

// Root
app.get('/', (c) => {
  return c.json({ message: 'Aura API v1.0' });
});

export default app;

// Local development
if (import.meta.main) {
  console.log('🚀 Server running on http://localhost:3000');
  
  Bun.serve({
    fetch: app.fetch,
    port: 3000,
  });
}
EOF
success "Создан backend/src/index.ts"

# Создание tsconfig.json
cat > backend/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "lib": ["ES2022"],
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "types": ["bun-types"]
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
EOF
success "Создан backend/tsconfig.json"

# Инструкции для следующих шагов
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Проект настроен! Следующие шаги:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Backend:"
echo "   cd backend"
echo "   cp .env.example .env"
echo "   # Добавь свои ключи в .env"
echo "   bun install"
echo "   bun run dev"
echo ""
echo "2️⃣  Database:"
echo "   supabase init"
echo "   supabase db push"
echo ""
echo "3️⃣  iOS App:"
echo "   Открой Xcode и создай новый проект 'Aura'"
echo "   Настрой Config.xcconfig с ключами"
echo ""
echo "4️⃣  Документация:"
echo "   Все готово в папке docs/"
echo "   Читай docs/MASTER_PROMPT.md для старта"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Используй Cursor и ссылайся на @docs/MASTER_PROMPT.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
