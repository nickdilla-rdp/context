# Context — Tauri 2 Desktop App

Менеджер промптов. Фронтенд: чистый HTML/CSS/JS.  
Бэкенд: Rust (Tauri 2). Установщик: `.msi` через WiX Toolset.

---

## Структура проекта

```
context-tauri/
├── src/
│   └── index.html          ← Фронтенд (адаптированный под Tauri)
├── src-tauri/
│   ├── src/
│   │   └── main.rs         ← Rust бэкенд (все команды)
│   ├── icons/              ← Иконки приложения
│   ├── capabilities/
│   │   └── default.json    ← Tauri 2 разрешения
│   ├── tauri.conf.json     ← Главный конфиг
│   ├── Cargo.toml          ← Rust зависимости
│   └── build.rs
├── package.json
└── README.md
```

---

## Требования

### 1. Rust
```powershell
winget install Rustlang.Rustup
rustup update stable
```

### 2. Node.js (только для CLI Tauri)
```powershell
winget install OpenJS.NodeJS.LTS
```

### 3. WebView2 Runtime
На Windows 10/11 уже встроен. Для старых машин — включить bootstrapper в tauri.conf.json
(уже настроено: `"type": "downloadBootstrapper"`).

### 4. WiX Toolset v4 (для сборки MSI)
```powershell
dotnet tool install --global wix
```
или через winget:
```powershell
winget install WixToolset.WixToolset
```

---

## Первый запуск

```powershell
# 1. Клонировать / распаковать папку context-tauri
cd context-tauri

# 2. Установить npm зависимости (только Tauri CLI)
npm install

# 3. Запустить в режиме разработки
npm run dev
```

---

## Сборка MSI установщика

```powershell
npm run build
```

Готовый файл появится здесь:
```
src-tauri/target/release/bundle/msi/Context_1.0.0_x64_ru-RU.msi
```

---

## Иконки (обязательно!)

Tauri требует набор иконок. Самый простой способ — сгенерировать из PNG 1024×1024:

```powershell
# Поместите icon.png (1024x1024) в src-tauri/icons/
# Затем выполните:
npm run tauri icon src-tauri/icons/icon.png
```

Это автоматически создаст все нужные размеры.

---

## Настройки WiX в tauri.conf.json

| Параметр | Описание |
|---|---|
| `language` | Язык установщика (`ru-RU`) |
| `upgradeCode` | **Замените** на свой GUID — генерирует: `[guid]::NewGuid()` в PowerShell |
| `installMode` | `perMachine` (для всех пользователей) или `perUser` |
| `shortcutName` | Название ярлыка в меню Пуск |
| `webviewInstallMode` | `downloadBootstrapper` — скачает WebView2 если нет |

### Генерация GUID (один раз):
```powershell
[guid]::NewGuid().ToString().ToUpper()
# Пример: A1B2C3D4-E5F6-7890-ABCD-EF1234567890
```

---

## Как работает API Bridge (pywebview → Tauri)

В `index.html` добавлен shim, который проксирует все старые вызовы:

```js
// Старый код (не трогаем):
window.pywebview.api.save_state(json)
window.pywebview.api.save_media(dataUri, filename)

// Shim направляет их в:
window.__TAURI__.core.invoke('save_state', { json })
window.__TAURI__.core.invoke('save_media', { dataUri, filename })
```

Все данные сохраняются в:
- **Windows**: `%APPDATA%\context\state.json` и `%APPDATA%\context\media\`

---

## Оптимизация памяти

В `Cargo.toml` настроен release-профиль:
- `lto = true` — Link-Time Optimization: меньше бинарник
- `codegen-units = 1` — лучший LTO
- `panic = "abort"` — нет unwinding стека
- `strip = true` — убираем debug-символы

**Ожидаемое потребление RAM: ~15–35 MB** (против 150–300 MB у Electron).

---

## Подпись кода (опционально, для production)

Без подписи Windows показывает предупреждение SmartScreen.

```json
// В tauri.conf.json, секция bundle.windows:
"certificateThumbprint": "ВАШ_ОТПЕЧАТОК_СЕРТИФИКАТА",
"digestAlgorithm": "sha256",
"timestampUrl": "http://timestamp.digicert.com"
```

Бесплатный вариант: self-signed сертификат (убирает ошибку, но не SmartScreen).  
Платный: Code Signing Certificate от DigiCert / Sectigo (~$70/год).

---

## Troubleshooting

**`error: failed to run custom build command for tauri-build`**  
→ Убедитесь что установлен `cargo` и Rust stable toolchain.

**MSI не собирается, нет WiX**  
→ `dotnet tool install --global wix` и перезапустите терминал.

**Белый экран при запуске**  
→ Проверьте путь `"frontendDist": "../src"` в `tauri.conf.json`.

**Окно без рамки не перетаскивается**  
→ Убедитесь что в `capabilities/default.json` есть `"core:window:allow-start-dragging"`.
