use std::{env, error::Error};

use ashpd::desktop::{
    global_shortcuts::{BindShortcutsOptions, GlobalShortcuts, NewShortcut},
    CreateSessionOptions,
};
use ashpd::{register_host_app, AppID};
use futures_util::StreamExt;

const APP_ID: &str = "dev.runnit.shortcutprobe";
const SHORTCUT_ID: &str = "shortcut-probe.toggle";
const PREFERRED_TRIGGER: &str = "<Control><Alt>space";

fn desktop_name() -> String {
    env::var("XDG_CURRENT_DESKTOP").unwrap_or_else(|_| "unknown".to_owned())
}

fn is_hyprland() -> bool {
    desktop_name()
        .split(':')
        .any(|name| name.eq_ignore_ascii_case("hyprland"))
        || env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some()
}

fn print_environment() {
    println!("desktop: {}", desktop_name());
    println!(
        "session: {}",
        env::var("XDG_SESSION_TYPE").unwrap_or_else(|_| "unknown".to_owned())
    );
    println!(
        "hyprland: {}",
        if is_hyprland() {
            "detected"
        } else {
            "not detected"
        }
    );
    println!("backend: XDG Global Shortcuts portal");

    if is_hyprland() {
        println!("integration: xdg-desktop-portal-hyprland");
    } else {
        println!("integration: active desktop portal implementation");
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    print_environment();

    let app_id = AppID::try_from(APP_ID)?;
    register_host_app(app_id).await?;
    println!("app id: {APP_ID}");

    let portal = GlobalShortcuts::new().await?;
    println!("portal version: {}", portal.version());

    let session = portal
        .create_session(CreateSessionOptions::default())
        .await?;
    let mut activated = portal.receive_activated().await?;
    let mut deactivated = portal.receive_deactivated().await?;

    let shortcut = NewShortcut::new(SHORTCUT_ID, "Trigger the shortcut event probe")
        .preferred_trigger(PREFERRED_TRIGGER);
    let request = portal
        .bind_shortcuts(&session, &[shortcut], None, BindShortcutsOptions::default())
        .await?;
    let response = request.response()?;

    if response.shortcuts().is_empty() {
        return Err("the portal returned no bound shortcuts".into());
    }

    for shortcut in response.shortcuts() {
        println!(
            "bound: id={} trigger={}",
            shortcut.id(),
            shortcut.trigger_description()
        );
    }

    println!("waiting for events; press the bound shortcut or Ctrl+C to exit");

    loop {
        tokio::select! {
            event = activated.next() => match event {
                Some(event) if event.shortcut_id() == SHORTCUT_ID => {
                    println!("pressed: id={} timestamp={:?}", event.shortcut_id(), event.timestamp());
                }
                Some(_) => {}
                None => return Err("portal activation event stream closed".into()),
            },
            event = deactivated.next() => match event {
                Some(event) if event.shortcut_id() == SHORTCUT_ID => {
                    println!("released: id={} timestamp={:?}", event.shortcut_id(), event.timestamp());
                }
                Some(_) => {}
                None => return Err("portal deactivation event stream closed".into()),
            },
            result = tokio::signal::ctrl_c() => {
                result?;
                println!("stopped");
                break;
            }
        }
    }

    Ok(())
}
