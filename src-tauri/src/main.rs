// Revix - A powerful task scheduling and productivity application
// Copyright (C) 2024-2025 imnexerio
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Repository: https://github.com/imnexerio/revix

// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::Manager;
use tauri_plugin_updater::UpdaterExt;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .setup(|app| {
            // Get the main window
            let window = app.get_webview_window("main").unwrap();

            // Show window when ready
            window.show().unwrap();

            // Check for updates in background
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                match handle.updater().check().await {
                    Ok(Some(update)) => {
                        println!("Update available: {}", update.version);
                        // Download and install the update
                        if let Err(e) = update.download_and_install(|_, _| {}, || {}).await {
                            eprintln!("Failed to install update: {}", e);
                        }
                    }
                    Ok(None) => {
                        println!("No updates available");
                    }
                    Err(e) => {
                        eprintln!("Failed to check for updates: {}", e);
                    }
                }
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
