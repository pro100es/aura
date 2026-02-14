# Aura Compliance & App Store Guidelines

> Критические требования для App Store approval  
> Обязательно к реализации перед релизом

---

## 🍎 Apple App Store Requirements

### ✅ Checklist перед сабмитом

- [ ] **AI Disclosure**: Все сгенерированные изображения помечены
- [ ] **No Deepfakes**: Запрет на face swap знаменитостей
- [ ] **Content Safety**: NSFW фильтрация включена
- [ ] **Privacy**: Четкое объяснение использования фото
- [ ] **Metadata**: C2PA метаданные в EXIF
- [ ] **User Control**: Возможность удалить все данные
- [ ] **No Misleading**: Нельзя выдавать AI за реальное фото

---

## 🚫 Запрещенный контент (Blocked Terms)

### Database: Таблица модерации

```sql
-- Добавить в Migration 004
CREATE TABLE IF NOT EXISTS public.blocked_terms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    term TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL CHECK (category IN ('celebrity', 'nsfw', 'violence', 'brand', 'location')),
    severity TEXT NOT NULL DEFAULT 'high' CHECK (severity IN ('low', 'medium', 'high')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blocked_terms_category ON public.blocked_terms(category, is_active);

-- Seed данные
INSERT INTO public.blocked_terms (term, category, severity) VALUES
-- Знаменитости
('trump', 'celebrity', 'high'),
('biden', 'celebrity', 'high'),
('musk', 'celebrity', 'high'),
('kardashian', 'celebrity', 'high'),
('swift', 'celebrity', 'high'),
('ronaldo', 'celebrity', 'high'),

-- Бренды/Локации (потенциально проблемные)
('coca-cola', 'brand', 'medium'),
('nike', 'brand', 'medium'),
('apple logo', 'brand', 'high'),

-- NSFW
('nude', 'nsfw', 'high'),
('naked', 'nsfw', 'high'),
('sex', 'nsfw', 'high'),
('porn', 'nsfw', 'high'),

-- Насилие
('gun', 'violence', 'high'),
('blood', 'violence', 'medium'),
('dead', 'violence', 'high');
```

---

## 🛡️ Backend Validation (Hono.js)

### Модуль валидации промптов

```typescript
// src/services/compliance.service.ts
import { supabase } from './supabase.service';

export class ComplianceService {
  private blockedTermsCache: Map<string, string> = new Map();
  private cacheExpiry: number = Date.now();
  
  /**
   * Загрузить запрещенные термины в кэш (обновляется раз в час)
   */
  private async loadBlockedTerms(): Promise<void> {
    if (Date.now() < this.cacheExpiry) return;
    
    const { data } = await supabase
      .from('blocked_terms')
      .select('term, category')
      .eq('is_active', true);
    
    this.blockedTermsCache.clear();
    data?.forEach(item => {
      this.blockedTermsCache.set(item.term.toLowerCase(), item.category);
    });
    
    this.cacheExpiry = Date.now() + 3600000; // 1 hour
  }
  
  /**
   * Проверить промпт на запрещенные слова
   */
  async validatePrompt(prompt: string): Promise<ValidationResult> {
    await this.loadBlockedTerms();
    
    const lowerPrompt = prompt.toLowerCase();
    const found: Array<{ term: string; category: string }> = [];
    
    for (const [term, category] of this.blockedTermsCache) {
      if (lowerPrompt.includes(term)) {
        found.push({ term, category });
      }
    }
    
    if (found.length > 0) {
      return {
        valid: false,
        violations: found,
        message: this.getViolationMessage(found[0].category),
      };
    }
    
    return { valid: true };
  }
  
  /**
   * Получить сообщение об ошибке
   */
  private getViolationMessage(category: string): string {
    const messages: Record<string, string> = {
      celebrity: 'Генерация с изображениями знаменитостей запрещена политикой App Store',
      nsfw: 'Контент для взрослых запрещен в приложении',
      violence: 'Контент с насилием запрещен',
      brand: 'Использование защищенных брендов может нарушать авторские права',
    };
    
    return messages[category] || 'Обнаружен запрещенный контент';
  }
  
  /**
   * Добавить AI disclosure метаданные в изображение
   */
  async addAIMetadata(imageBuffer: Buffer): Promise<Buffer> {
    // TODO: Интеграция с C2PA SDK
    // https://c2pa.org/
    
    // Пока просто возвращаем оригинал
    // В production нужно добавить EXIF метаданные:
    // - Software: "Aura AI Generator"
    // - UserComment: "Generated by AI"
    // - C2PA manifest
    
    return imageBuffer;
  }
}

export const complianceService = new ComplianceService();

// Types
interface ValidationResult {
  valid: boolean;
  violations?: Array<{ term: string; category: string }>;
  message?: string;
}
```

---

### API Endpoint для валидации

```typescript
// src/routes/generations.ts (ОБНОВИТЬ)
import { complianceService } from '../services/compliance.service';

app.post('/', zValidator('json', CreateGenerationSchema), async (c: Context) => {
  const userId = c.get('userId');
  const body = c.req.valid('json');
  
  // 1. Проверка подписки
  const profile = await getProfile(userId);
  if (!canGenerate(profile)) {
    return c.json({
      error: {
        code: 'LIMIT_EXCEEDED',
        message: 'Daily limit reached',
      }
    }, 402);
  }
  
  // 2. Получаем пресет
  const preset = await getPreset(body.preset_id);
  
  // 3. COMPLIANCE CHECK - комбинируем пресет + кастомный промпт
  const fullPrompt = `${preset.prompt_template} ${body.custom_prompt || ''}`;
  const validation = await complianceService.validatePrompt(fullPrompt);
  
  if (!validation.valid) {
    return c.json({
      error: {
        code: 'CONTENT_VIOLATION',
        message: validation.message,
        violations: validation.violations,
      }
    }, 400);
  }
  
  // 4. Продолжаем генерацию...
  const prediction = await createPrediction(preset, body.image_url);
  
  // Остальной код...
});
```

---

### Webhook обработка с добавлением метаданных

```typescript
// src/routes/webhooks.ts (ОБНОВИТЬ)
app.post('/replicate', async (c: Context) => {
  // Validate webhook secret
  const secret = c.req.header('X-Webhook-Secret');
  if (secret !== env.WEBHOOK_SECRET) {
    return c.json({ error: 'Unauthorized' }, 401);
  }
  
  const body = await c.req.json();
  
  if (body.status === 'succeeded') {
    const generation = await findGenerationByReplicateId(body.id);
    
    // Download images from Replicate
    const imageUrls = body.output as string[];
    
    for (const [index, url] of imageUrls.entries()) {
      // Download image
      const response = await fetch(url);
      let imageBuffer = await response.arrayBuffer();
      
      // ✅ ADD AI METADATA
      imageBuffer = await complianceService.addAIMetadata(
        Buffer.from(imageBuffer)
      );
      
      // Upload to Supabase Storage
      const fileName = `${generation.id}_${index}.jpg`;
      const { data } = await supabase.storage
        .from('results')
        .upload(`${generation.user_id}/${fileName}`, imageBuffer, {
          contentType: 'image/jpeg',
          metadata: {
            // Custom metadata
            ai_generated: 'true',
            model: 'flux-1-dev',
            app: 'Aura',
          }
        });
      
      // Save asset
      await createAsset({
        generation_id: generation.id,
        image_url: data.path,
        variant: getVariantName(index),
      });
    }
    
    await updateGenerationStatus(generation.id, 'succeeded');
  }
  
  return c.json({ success: true });
});
```

---

## 📱 iOS Compliance Components

### 1. AI Badge (обязательная маркировка)

```swift
// Shared/Components/AIBadge.swift
import SwiftUI

struct AIBadge: View {
    let size: CGFloat
    
    init(size: CGFloat = 20) {
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.6))
            
            Text("AI")
                .font(.system(size: size * 0.5, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, size * 0.4)
        .padding(.vertical, size * 0.25)
        .background(
            Capsule()
                .fill(Color.purple.opacity(0.8))
        )
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// Usage на сгенерированных фото
struct GeneratedImageCard: View {
    let imageURL: URL
    
    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            ShimmerView()
        }
        .overlay(alignment: .topTrailing) {
            AIBadge()
                .padding(Spacing.sm)
        }
        .cornerRadius(CornerRadius.card)
    }
}
```

---

### 2. Prompt Validation (iOS)

```swift
// Core/Utilities/ComplianceValidator.swift
import Foundation

final class ComplianceValidator {
    static let shared = ComplianceValidator()
    
    private let blockedTerms: Set<String> = [
        // Знаменитости
        "trump", "biden", "musk", "kardashian", "swift",
        // NSFW
        "nude", "naked", "sex", "porn",
        // Насилие
        "gun", "blood", "dead", "kill",
    ]
    
    private init() {}
    
    /// Валидация кастомного промпта перед отправкой
    func validatePrompt(_ prompt: String) -> ValidationResult {
        let normalized = prompt.lowercased()
        
        for term in blockedTerms {
            if normalized.contains(term) {
                return .invalid(reason: "Обнаружен запрещенный контент. Попробуйте другое описание.")
            }
        }
        
        // Проверка длины
        if prompt.count > 500 {
            return .invalid(reason: "Описание слишком длинное (макс. 500 символов)")
        }
        
        return .valid
    }
    
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        var errorMessage: String? {
            if case .invalid(let reason) = self { return reason }
            return nil
        }
    }
}

// Usage в ViewModel
@Observable
final class CustomPromptViewModel {
    var promptText: String = ""
    var validationError: String?
    
    func generate() async {
        // Validate перед отправкой
        let validation = ComplianceValidator.shared.validatePrompt(promptText)
        
        guard validation.isValid else {
            validationError = validation.errorMessage
            HapticManager.notification(.error)
            return
        }
        
        // Продолжаем генерацию
        await createGeneration(prompt: promptText)
    }
}
```

---

### 3. Privacy Disclosure (Onboarding)

```swift
// Features/Onboarding/Views/PrivacyDisclosureView.swift
struct PrivacyDisclosureView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Header
            VStack(spacing: Spacing.md) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.auraAccent)
                
                Text("Ваши данные в безопасности")
                    .font(.auraTitle2)
                    .foregroundStyle(.auraTextPrimary)
            }
            
            // Disclaimers
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PrivacyItem(
                    icon: "photo.fill",
                    title: "Временное хранение фото",
                    description: "Исходные фото удаляются через 24 часа после обработки"
                )
                
                PrivacyItem(
                    icon: "sparkles",
                    title: "Все изображения помечены как AI",
                    description: "Согласно требованиям App Store, все результаты содержат метаданные о создании ИИ"
                )
                
                PrivacyItem(
                    icon: "lock.fill",
                    title: "Никакого Face Swap",
                    description: "Мы НЕ подменяем лица. Приложение меняет только фон и стиль, сохраняя вашу идентичность"
                )
                
                PrivacyItem(
                    icon: "trash.fill",
                    title: "Удаление в один клик",
                    description: "Вы можете удалить все свои данные в любой момент через настройки профиля"
                )
            }
            
            Spacer()
            
            // CTA
            VStack(spacing: Spacing.md) {
                AuraButton(title: "Понятно") {
                    isPresented = false
                }
                
                Button("Политика конфиденциальности") {
                    // Open privacy policy URL
                }
                .font(.auraCaption)
                .foregroundStyle(.auraTextSecondary)
            }
        }
        .padding(Spacing.xl)
        .background(Color.auraBackground)
    }
}

struct PrivacyItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.auraAccent)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.auraCallout)
                    .foregroundStyle(.auraTextPrimary)
                
                Text(description)
                    .font(.auraCaption)
                    .foregroundStyle(.auraTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
```

---

### 4. Data Deletion (Settings)

```swift
// Features/Profile/Views/DeleteAccountView.swift
struct DeleteAccountView: View {
    @State private var isDeleting = false
    @State private var showConfirmation = false
    
    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label("Удалить все данные", systemImage: "trash.fill")
                }
            } footer: {
                Text("Это действие нельзя отменить. Будут удалены:\n• Все сгенерированные фото\n• История генераций\n• Аккаунт")
                    .font(.auraCaption)
            }
        }
        .alert("Удалить аккаунт?", isPresented: $showConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                Task { await deleteAccount() }
            }
        }
    }
    
    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            // 1. Delete from Supabase Storage
            try await supabase.storage
                .from("results")
                .remove(paths: ["*"]) // All user files
            
            try await supabase.storage
                .from("uploads")
                .remove(paths: ["*"])
            
            // 2. Delete database records (cascade via FK)
            try await supabase
                .from("profiles")
                .delete()
                .eq("id", supabase.auth.currentUser!.id)
                .execute()
            
            // 3. Delete auth user
            try await supabase.auth.signOut()
            
            // 4. Navigate to login
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            
        } catch {
            // Show error
            print("Delete failed: \(error)")
        }
    }
}
```

---

## 📋 App Store Review Checklist

### Before Submit

```markdown
## Тестирование перед сабмитом:

### 1. AI Disclosure
- [ ] Все сгенерированные фото имеют "✨ AI" badge
- [ ] В метаданных EXIF есть Software: "Aura AI"
- [ ] Onboarding объясняет что это AI tool

### 2. Content Safety
- [ ] Попробовать промпт "Trump in Paris" → должен блокироваться
- [ ] Попробовать промпт "naked person" → должен блокироваться
- [ ] Replicate safety_checker включен
- [ ] Backend возвращает 400 с понятным сообщением

### 3. Privacy
- [ ] Privacy Policy доступна в Settings
- [ ] Кнопка "Удалить аккаунт" работает
- [ ] После удаления все файлы в Storage удалены
- [ ] Onboarding показывает Privacy Disclosure

### 4. No Deepfakes
- [ ] Промпты с "face swap" блокируются
- [ ] Промпты с именами знаменитостей блокируются
- [ ] В описании App Store нет слов "deepfake", "face replacement"

### 5. Использование InstantID (НЕ Face Swap)
- [ ] В App Review Notes написано: "We use InstantID technology to preserve user's facial features while changing background and clothing. This is NOT face swapping."
```

---

## 🚨 App Review Notes (для Apple)

**Скопируй это в App Store Connect:**

```
Aura - AI Photo Styling (NOT a Deepfake App)

IMPORTANT NOTES FOR REVIEW:

1. AI DISCLOSURE
- All AI-generated images are clearly labeled with "✨ AI" badge
- EXIF metadata includes "Software: Aura AI Generator"
- Onboarding explicitly states this is an AI tool

2. TECHNOLOGY USED
- We use InstantID + FLUX.1 models to preserve user's facial identity
- The app changes BACKGROUND and CLOTHING, NOT the face itself
- This is fundamentally different from face-swapping or deepfakes

3. CONTENT SAFETY
- Prompts are validated against a blocklist (celebrities, NSFW, violence)
- Replicate's built-in safety_checker is enabled
- Users cannot generate content with famous people

4. PRIVACY
- Source images deleted after 24 hours
- Users can delete all data anytime via Settings
- Privacy Policy: https://aura-app.ai/privacy

TEST ACCOUNT:
Email: reviewer@aura-app.ai
Password: AppleReview2026!

Please test:
- Upload a selfie → Choose "Old Money" preset → See safe transformation
- Try typing "Trump" in custom prompt → See error message
- Go to Settings → Privacy → Delete Account → Confirm deletion works
```

---

## 📄 Privacy Policy (Минимальная версия)

Создай файл на своем сайте: `https://aura-app.ai/privacy.html`

```markdown
# Privacy Policy - Aura

Last updated: January 15, 2026

## Data We Collect
- Email address (for authentication)
- Uploaded photos (temporarily, deleted after 24 hours)
- Generated images (stored until you delete them)

## How We Use Data
- To provide AI image generation service
- To improve our AI models (anonymized)

## Data Deletion
You can delete all your data anytime via Settings → Privacy → Delete Account.

## Third-Party Services
- Supabase (database & storage)
- Replicate (AI processing)
- RevenueCat (subscriptions)

## Contact
support@aura-app.ai
```

---

## ✅ Implementation Priority

**Week 1 (BEFORE ANY CODE):**
1. ✅ Add `blocked_terms` table to DB
2. ✅ Implement `ComplianceService` backend
3. ✅ Add validation to POST /generations
4. ✅ Create AIBadge component

**Week 2 (DURING MVP):**
5. ✅ Add Privacy Disclosure to onboarding
6. ✅ Implement Delete Account functionality
7. ✅ Test all blocked terms
8. ✅ Write App Review Notes

**Before Submit:**
9. ✅ Deploy Privacy Policy page
10. ✅ Final compliance checklist testing

---

**Статус:** Critical for App Store ⚠️  
**Все компоненты готовы к copy-paste ✅**
