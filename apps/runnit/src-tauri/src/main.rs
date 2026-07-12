mod config;
pub mod sandbox;

use tauri::{WebviewUrl, WebviewWindowBuilder};

const FALLBACK_SIZE: (f64, f64) = (960.0, 600.0);

use config::{AppConfig, ConfigStore};
use sandbox::SandboxPolicy;

fn primary_window_size(app: &tauri::App, size_ratio: f64) -> tauri::Result<(f64, f64)> {
    let size = app.primary_monitor()?.map(|monitor| {
        let physical_size = monitor.size();
        let scale_factor = monitor.scale_factor();

        (
            f64::from(physical_size.width) / scale_factor * size_ratio,
            f64::from(physical_size.height) / scale_factor * size_ratio,
        )
    });

    Ok(size.unwrap_or(FALLBACK_SIZE))
}

fn create_main_window(
    app: &mut tauri::App,
    config: &AppConfig,
) -> Result<(), Box<dyn std::error::Error>> {
    let (width, height) = primary_window_size(app, config.window.size_ratio)?;

    WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
        .title("Runnit")
        .inner_size(width, height)
        .center()
        .transparent(true)
        .decorations(false)
        .shadow(false)
        .always_on_top(config.window.always_on_top)
        .resizable(config.window.resizable)
        .build()?;

    Ok(())
}

fn main() {
    // Native Wayland transparency is unstable with WebKitGTK on the target system.
    #[cfg(target_os = "linux")]
    {
        std::env::set_var("GDK_BACKEND", "x11");
        // Avoid WebKitGTK's GBM/DMABUF renderer, which fails for this
        // transparent XWayland surface on some Mesa drivers.
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    }

    tauri::Builder::default()
        .setup(|app| {
            let store = ConfigStore::discover()?;
            let config = store.load_or_create()?;
            let data_root = store
                .path()
                .parent()
                .expect("config path always has a parent")
                .join("extensions-data");
            let _sandbox = SandboxPolicy::new(config.sandbox.clone(), data_root)?;
            eprintln!("Runnit config: {}", store.path().display());
            create_main_window(app, &config)
        })
        .run(tauri::generate_context!())
        .expect("failed to run Runnit");
}
