// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{Manager, WindowEvent};

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();
            
            // Show window when ready
            window.show().unwrap();

            // ===== SECURITY: Disable DevTools in production =====
            #[cfg(not(debug_assertions))]
            {
                // DevTools are automatically disabled in release builds
            }

            // ===== SECURITY: Inject script to block keyboard shortcuts & right-click =====
            #[cfg(not(debug_assertions))]
            {
                let security_script = r#"
                    // Disable right-click context menu
                    document.addEventListener('contextmenu', (e) => {
                        e.preventDefault();
                        return false;
                    });

                    // Disable keyboard shortcuts for DevTools
                    document.addEventListener('keydown', (e) => {
                        // F12
                        if (e.key === 'F12') {
                            e.preventDefault();
                            return false;
                        }
                        // Ctrl+Shift+I (DevTools)
                        if (e.ctrlKey && e.shiftKey && e.key === 'I') {
                            e.preventDefault();
                            return false;
                        }
                        // Ctrl+Shift+J (Console)
                        if (e.ctrlKey && e.shiftKey && e.key === 'J') {
                            e.preventDefault();
                            return false;
                        }
                        // Ctrl+Shift+C (Element Inspector)
                        if (e.ctrlKey && e.shiftKey && e.key === 'C') {
                            e.preventDefault();
                            return false;
                        }
                        // Ctrl+U (View Source)
                        if (e.ctrlKey && e.key === 'u') {
                            e.preventDefault();
                            return false;
                        }
                    });

                    console.log('Security features enabled');
                "#;

                window.eval(security_script).unwrap_or_else(|e| {
                    eprintln!("Failed to inject security script: {}", e);
                });
            }
            
            Ok(())
        })
        .on_window_event(|_window, event| {
            // Handle window events for additional security
            match event {
                WindowEvent::CloseRequested { .. } => {
                    // Allow close
                }
                _ => {}
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
