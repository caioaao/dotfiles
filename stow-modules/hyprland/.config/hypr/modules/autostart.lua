-- Autostart (was exec-once).
-- Runs on session start only, not on every config reload.
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("quickshell")
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
