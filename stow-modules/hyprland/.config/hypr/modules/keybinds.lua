-- Keybindings (was bind).

local mod = "SUPER"

-- Terminal
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("ghostty"))

-- App launcher
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("qs ipc call launcher toggle"))

-- Close window (graceful close request)
hl.bind(mod .. " + Q", hl.dsp.window.close())

-- Tile / move windows
hl.bind(mod .. " + ALT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + ALT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + ALT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + ALT + Down", hl.dsp.window.move({ direction = "d" }))

-- Move window to other monitor
hl.bind(mod .. " + ALT + SHIFT + Left", hl.dsp.window.move({ monitor = "l" }))
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
hl.bind(mod .. " + Tab", hl.dsp.window.cycle_next())
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

-- Workspace switching / move window to workspace
for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"))

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("grimblast copysave area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copysave screen"))

-- Lock screen
hl.bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))

-- Logout
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exit())

-- Resize with mod + right mouse button (was bindm)
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move with mod + left mouse button (was bindm)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
