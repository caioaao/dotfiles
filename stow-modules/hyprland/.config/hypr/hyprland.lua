-- Hyprland config (Lua).
-- Migrated from hyprland.conf (hyprlang) for Hyprland 0.55+.
-- https://wiki.hypr.land/Configuring/Start/

local mod = "SUPER"

-- ── Monitor ────────────────────────────────────────────────────────────────
-- Fallback rule. nwg-displays (>= 0.4.3) writes ~/.config/hypr/monitors.lua,
-- which overrides this when present.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- nwg-displays output (was: source = ~/.config/hypr/monitors.conf).
-- monitors.conf is hyprlang and no longer loads; nwg-displays >= 0.4.3 writes
-- monitors.lua alongside it. pcall so a missing file can't kill the config.
pcall(require, "monitors")

-- ── Autostart (was exec-once) ──────────────────────────────────────────────
-- Runs on session start only, not on every config reload.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("1password --silent")
    -- Secret Service provider for Chromium cookie/password encryption
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    -- polkit agent for GUI auth dialogs
    hl.exec_cmd("/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1")
end)

-- ── Cedilla fix: use PT-BR compose tables (dead_acute + c = ç) ────────────
hl.env("LC_CTYPE", "pt_BR.UTF-8")
-- ── Dead keys fix: GTK 4.20+ no longer handles dead keys on Wayland ───────
hl.env("GTK_IM_MODULE", "simple")

-- ── Input / General / Misc / Decoration / Animations / Dwindle ─────────────
hl.config({
    input = {
        kb_layout    = "us,us",
        kb_variant   = ",intl",
        kb_options   = "grp:ctrl_space_toggle",
        follow_mouse = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,  -- was tap-to-click
            drag_lock      = 1,     -- was bool; now int 0/1/2 (1 = timeout)
        },
    },

    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,
        col = {
            active_border   = "rgba(88888aff)",
            inactive_border = "rgba(45475aff)",
        },
        layout = "dwindle",
    },

    misc = {
        disable_hyprland_logo = true,
    },

    decoration = {
        rounding = 6,
        blur   = { enabled = false },
        shadow = { enabled = false },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },
})

-- ── Animations (was: animation = windows, 1, 3, default) ───────────────────
-- Old format: NAME, ONOFF, SPEED, CURVE -> speed 3 = 300ms.
hl.animation({ leaf = "windows",    enabled = true, speed = 3, curve = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3, curve = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, curve = "default" })

-- ── Window Rules (was windowrulev2) ────────────────────────────────────────
hl.window_rule({ match = { class = "^1Password$" }, float = true })
hl.window_rule({ match = { class = "^polkit-gnome-authentication-agent-1$" }, float = true })
hl.window_rule({ match = { title = "^Open File" }, float = true })
hl.window_rule({ match = { title = "^Save As" }, float = true })

-- ── Keybindings (was bind) ─────────────────────────────────────────────────
-- Terminal
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("ghostty"))

-- App launcher
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("fuzzel"))

-- Close window (graceful close request)
hl.bind(mod .. " + Q", hl.dsp.window.close())

-- Tile / move windows
hl.bind(mod .. " + ALT + Left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + ALT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + ALT + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + ALT + Down",  hl.dsp.window.move({ direction = "d" }))

-- Move window to other monitor
hl.bind(mod .. " + ALT + SHIFT + Left",  hl.dsp.window.move({ monitor = "l" }))
hl.bind(mod .. " + ALT + SHIFT + Right", hl.dsp.window.move({ monitor = "r" }))

-- Toggle maximize (keeps bar visible)
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- True fullscreen
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Toggle floating
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Focus movement
hl.bind(mod .. " + h", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + l", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + k", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + j", hl.dsp.focus({ direction = "d" }))

-- Cycle windows (useful when maximized)
hl.bind(mod .. " + Tab",         hl.dsp.window.cycle_next())
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

-- Workspace switching / move window to workspace
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pamixer -t"))

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))

-- Screenshots
hl.bind("Print",         hl.dsp.exec_cmd("grimblast copysave area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copysave screen"))

-- Lock screen
hl.bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))

-- Logout
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exit())

-- Resize with mod + right mouse button (was bindm)
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move with mod + left mouse button (was bindm)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
