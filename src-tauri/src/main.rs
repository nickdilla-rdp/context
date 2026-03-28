// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::menu::{Menu, MenuItem};
use base64::{engine::general_purpose, Engine as _};

// ── Data directory: рядом с exe ───────────────────────────────────────────────
// Все данные хранятся в папке установки программы (portable mode):
//   <install_dir>\data\state.json
//   <install_dir>\data\media\

fn data_dir(app: &AppHandle) -> PathBuf {
    // exe находится в <install_dir>\context.exe
    // данные кладём в <install_dir>\data\
    let exe = std::env::current_exe().expect("Cannot get exe path");
    let install_dir = exe.parent().expect("Cannot get install dir");
    install_dir.join("data")
}

fn media_dir(app: &AppHandle) -> PathBuf {
    data_dir(app).join("media")
}

fn state_file(app: &AppHandle) -> PathBuf {
    data_dir(app).join("state.json")
}

fn ensure_dirs(app: &AppHandle) {
    let _ = fs::create_dir_all(data_dir(app));
    let _ = fs::create_dir_all(media_dir(app));
}

fn show_window(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
    }
}

// ── Tauri commands ────────────────────────────────────────────────────────────

#[tauri::command]
fn save_state(app: AppHandle, json: String) -> Result<(), String> {
    ensure_dirs(&app);
    fs::write(state_file(&app), json).map_err(|e| e.to_string())
}

#[tauri::command]
fn load_state(app: AppHandle) -> Result<String, String> {
    let path = state_file(&app);
    if path.exists() {
        fs::read_to_string(path).map_err(|e| e.to_string())
    } else {
        Ok(String::new())
    }
}

#[tauri::command]
fn save_media(app: AppHandle, data_uri: String, filename: String) -> Result<String, String> {
    ensure_dirs(&app);
    let b64 = data_uri.splitn(2, ',').nth(1).ok_or("Invalid data URI")?;
    let bytes = general_purpose::STANDARD.decode(b64).map_err(|e| e.to_string())?;
    let key = format!(
        "{}_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis(),
        sanitize_filename(&filename)
    );
    let dest = media_dir(&app).join(&key);
    fs::write(&dest, bytes).map_err(|e| e.to_string())?;
    Ok(format!("media://{}", key))
}

#[tauri::command]
fn load_media(app: AppHandle, key: String) -> Result<String, String> {
    let path = media_dir(&app).join(&key);
    if !path.exists() {
        return Err(format!("Media not found: {}", key));
    }
    let bytes = fs::read(&path).map_err(|e| e.to_string())?;
    let b64 = general_purpose::STANDARD.encode(&bytes);
    let mime = guess_mime(&key);
    Ok(format!("data:{};base64,{}", mime, b64))
}

#[tauri::command]
fn delete_media(app: AppHandle, key: String) -> Result<(), String> {
    let path = media_dir(&app).join(&key);
    if path.exists() {
        fs::remove_file(path).map_err(|e| e.to_string())
    } else {
        Ok(())
    }
}

#[tauri::command]
fn load_texture(app: AppHandle) -> Result<String, String> {
    load_bundled_texture(&app, "texture_dark.png")
}

#[tauri::command]
fn load_texture_light(app: AppHandle) -> Result<String, String> {
    load_bundled_texture(&app, "texture_light.png")
}

fn load_bundled_texture(app: &AppHandle, name: &str) -> Result<String, String> {
    // Текстуры лежат рядом с exe в папке assets\
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let install_dir = exe.parent().ok_or("Cannot get install dir")?;
    let path = install_dir.join("assets").join(name);
    if path.exists() {
        let bytes = fs::read(&path).map_err(|e| e.to_string())?;
        let b64 = general_purpose::STANDARD.encode(&bytes);
        Ok(format!("data:image/png;base64,{}", b64))
    } else {
        Err(format!("Texture not found: {}", name))
    }
}

// ── Window controls ───────────────────────────────────────────────────────────

#[tauri::command]
fn win_minimize(window: tauri::Window) {
    let _ = window.minimize();
}

#[tauri::command]
fn win_maximize(window: tauri::Window) {
    if window.is_maximized().unwrap_or(false) {
        let _ = window.unmaximize();
    } else {
        let _ = window.maximize();
    }
}

#[tauri::command]
fn win_close(window: tauri::Window) {
    let _ = window.hide();
}

// Возвращает путь к папке с данными (для отладки)
#[tauri::command]
fn get_data_path(app: AppHandle) -> String {
    data_dir(&app).to_string_lossy().to_string()
}

// ── Utilities ─────────────────────────────────────────────────────────────────

fn sanitize_filename(name: &str) -> String {
    name.chars()
        .map(|c| if c.is_alphanumeric() || c == '.' || c == '-' { c } else { '_' })
        .collect()
}

fn guess_mime(filename: &str) -> &'static str {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" => "image/jpeg",
        "png"          => "image/png",
        "gif"          => "image/gif",
        "webp"         => "image/webp",
        "svg"          => "image/svg+xml",
        _              => "application/octet-stream",
    }
}

// ── Entry point ───────────────────────────────────────────────────────────────

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            show_window(app);
        }))
        .plugin(tauri_plugin_shell::init())
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .setup(|app| {
            let show_item = MenuItem::with_id(app, "show", "Открыть Context", true, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "Выйти",           true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_item, &quit_item])?;

            TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .tooltip("Context")
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event {
                        show_window(tray.app_handle());
                    }
                })
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => show_window(app),
                    "quit" => app.exit(0),
                    _ => {}
                })
                .build(app)?;

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            save_state,
            load_state,
            save_media,
            load_media,
            delete_media,
            load_texture,
            load_texture_light,
            win_minimize,
            win_maximize,
            win_close,
            get_data_path,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
