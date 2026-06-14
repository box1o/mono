local script = os.getenv("HOME") .. "/.local/share/bin"

local colors = {
    border = "rgba(2d2a2ecc)",
    border_active = "rgba(625e5acc)",
    shadow = "rgba(00000055)",
}

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "nautilus"
local browser = "zen-browser --blank-window file:///home/pixel/mono/configs/browser/index.html"
local launcher = script .. "/rofi.sh"
local dcmd = script .. "/dcmd"

hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-2", mode = "1920x1080@144", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("GTK_FONT_NAME", "Adwaita Sans 11")
hl.env("QT_FONT_NAME", "Adwaita Sans")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "Breeze")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("waybar")
    hl.exec_cmd(script .. "/wallpaper-picker.sh --restore")
    hl.exec_cmd("dunst")
    hl.exec_cmd(script .. "/theme.sh apply")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd(script .. "/desktop-services.sh")
end)

hl.config({
    general = {
        gaps_in = 1,
        gaps_out = 2,
        border_size = 1,
        col = {
            active_border = colors.border_active,
            inactive_border = colors.border,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 4,
        rounding_power = 4,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 8,
            render_power = 2,
            color = colors.shadow,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.08,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
    input = {
        kb_layout = "us",
        kb_options = "caps:swapescape",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 3.5, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 2.8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "default" })

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

hl.window_rule({ match = { title = "^(dcmd)$" }, float = true, center = true, size = { 1300, 850 } })
hl.window_rule({ match = { class = "^(Rofi)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol)$" }, float = true, center = true, size = { 760, 520 } })
hl.window_rule({ match = { class = "^(kicad)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.freecad\\.FreeCAD)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus|nautilus)$" }, float = true })
hl.window_rule({ match = { class = "^(Spotify|spotify)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.(Calendar|Calculator|Clocks|Weather|Characters|Logs|DiskUtility|FontViewer|Loupe|TextEditor|Snapshot))$" }, float = true })
hl.window_rule({ match = { class = "^(gnome-disks|nm-connection-editor|blueman-manager|blueman-adapters|system-config-printer)$" }, float = true })
hl.window_rule({ match = { class = "^(qt5ct|qt6ct|kvantummanager|systemsettings|plasma-systemmonitor)$" }, float = true })
hl.window_rule({ match = { class = "^(easyeffects|com\\.github\\.wwmm\\.easyeffects|helvum|org\\.pipewire\\.Helvum|qpwgraph|org\\.rncbc\\.qpwgraph)$" }, float = true })
hl.window_rule({ match = { modal = true }, float = true, center = true })
hl.window_rule({ match = { class = "^(Bitwarden|bitwarden|Spotify|spotify|pavucontrol|org\\.pulseaudio\\.pavucontrol|org\\.gnome\\.Calculator)$" }, workspace = "special:magic silent" })

hl.bind("ALT + SHIFT + A", hl.dsp.exec_cmd(launcher))
hl.bind("ALT + SHIFT + D", hl.dsp.exec_cmd(terminal))
hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd(browser))
hl.bind("ALT + SHIFT + F", hl.dsp.exec_cmd(fileManager))
hl.bind("ALT + SHIFT + G", hl.dsp.exec_cmd(dcmd))

hl.bind("ALT + V", hl.dsp.exec_cmd(script .. "/clipboard.sh"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(script .. "/pipfolow.sh"))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd(terminal .. " -e " .. script .. "/pkg.sh"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(terminal .. " -e " .. script .. "/rdp.sh"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(script .. "/waybar.sh"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(script .. "/win-vm.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(script .. "/wallpaper-picker.sh"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(script .. "/theme.sh toggle"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(script .. "/portal-restart.sh"))

hl.bind("ALT + SHIFT + C", hl.dsp.window.kill())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(script .. "/session.sh menu"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd(script .. "/image-colors.sh"))
hl.bind("ALT + Q", hl.dsp.exec_cmd(script .. "/session.sh lock"))
hl.bind("ALT + SHIFT + Q", hl.dsp.exec_cmd("wlogout"))

hl.bind("ALT + N", hl.dsp.exec_cmd("kitty -e nmtui"))
hl.bind("ALT + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + SHIFT + W", hl.dsp.window.fullscreen())

hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind("ALT + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + N", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind("ALT + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("ALT + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind("XF86AudioMute", hl.dsp.exec_cmd(script .. "/volumecontrol.sh m"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(script .. "/volumecontrol.sh d"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(script .. "/volumecontrol.sh i"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(script .. "/brightnesscontrol.sh i"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(script .. "/brightnesscontrol.sh d"), { locked = true, repeating = true })

hl.bind("Print", hl.dsp.exec_cmd(script .. "/screenshot.sh d"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(script .. "/screenshot.sh p"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(script .. "/screenshot.sh w"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(script .. "/screenshot.sh edit"))
