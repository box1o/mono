# Shortcut Probe

Small standalone test for Linux global shortcut registration and event delivery. It does not depend on or modify Runnit.

The probe uses the XDG Global Shortcuts portal. On Hyprland it detects the compositor and expects `xdg-desktop-portal-hyprland`; on other desktops it uses whichever portal implementation is active.

## Run

```bash
cd /home/pixel/mono/apps/shortcut-probe
install -Dm644 dev.runnit.shortcutprobe.desktop ~/.local/share/applications/dev.runnit.shortcutprobe.desktop
cargo run
```

The portal may show a shortcut configuration dialog. Accept or choose a shortcut, then press it. The terminal should print both `pressed` and `released` events.

On Hyprland, the portal registers an action but does not assign the requested trigger itself. The Mono Hyprland config forwards this test key to the registered action:

```text
Alt+Shift+P
```

The relevant Lua dispatcher is:

```lua
hl.dsp.global("dev.runnit.shortcutprobe:shortcut-probe.toggle")
```

Stop the probe with `Ctrl+C`. The portal session and its temporary shortcut registration are released when the process exits.

The desktop entry provides the stable `dev.runnit.shortcutprobe` identity required by current portal releases. The probe registers that host-app identity before creating its shortcut session.

## Why a portal

- Wayland intentionally prevents ordinary applications from observing raw global key events.
- Hyprland's event socket reports compositor/window events, not arbitrary key presses.
- The Global Shortcuts portal is the supported cross-desktop registration API.
- Raw evdev/libinput capture would require elevated device access and is not an appropriate application shortcut mechanism.
