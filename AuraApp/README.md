# Aura iOS App

## Создание проекта в Xcode

1. Открой Xcode → File → New → Project
2. Выбери **iOS** → **App** → Next
3. Настрой:
   - Product Name: **Aura**
   - Team: твоя команда
   - Organization Identifier: `com.aura` (или свой)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
4. Сохрани в папку `aura/AuraApp` (перезапиши содержимое или выбери другую папку и скопируй файлы)

## Добавление исходников

1. В Project Navigator удали автоматически созданные `ContentView.swift` и `Assets.xcassets` (если есть)
2. Правый клик на папку Aura → Add Files to "Aura"
3. Выбери папки: `App`, `Core`, `Features`, `Shared`, `Resources`
4. Убедись, что **Copy items if needed** снят (файлы уже в проекте)
5. Target: Aura

## Настройка Build Settings

1. Target Aura → Build Settings
2. Поиск **Info.plist File** → укажи `Resources/Info.plist`
3. Поиск **Code Signing** → настрой для своей команды

## Конфигурация

1. Target → Info → Custom iOS Target Properties
2. Добавь (или используй xcconfig):
   - `SUPABASE_URL` — URL проекта Supabase
   - `SUPABASE_ANON_KEY` — anon key
   - `API_BASE_URL_PROD` — `https://aura-production-91c3.up.railway.app`

Либо создай Configuration Settings File (Config.xcconfig) и добавь переменные в Build Settings.

## Зависимости (Swift Package Manager)

File → Add Package Dependencies:

1. **Supabase Swift**: `https://github.com/supabase/supabase-swift`
2. **PhotosUI** — встроен в iOS 16+

## Следующие шаги

- [ ] Интегрировать Supabase SDK для auth и Storage (см. `StorageService.swift`)
- [ ] Реализовать загрузку фото в Supabase Storage в `StorageService.uploadImage`
- [ ] Добавить камеру (UIImagePickerController с sourceType .camera)
- [ ] Подключить RevenueCat для Paywall
