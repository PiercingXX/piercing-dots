-- Workspace rules
hl.workspace_rule({ workspace = "1", monitor = "DP-1" })
hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "DP-2" })
hl.workspace_rule({ workspace = "6" })
hl.workspace_rule({ workspace = "7" })
hl.workspace_rule({ workspace = "8" })
hl.workspace_rule({ workspace = "9" })
hl.workspace_rule({ workspace = "10" })

-- Window rules
hl.window_rule({
    name = "gnome-calculator",
    match = { class = "org.gnome.Calculator" },
    float = true,
    center = true,
})

hl.window_rule({ name = "pavucontrol", match = { class = "pavucontrol" }, float = true })
hl.window_rule({ name = "blueman-manager", match = { class = "blueman-manager" }, float = true })
hl.window_rule({
    name = "ulauncher",
    match = { class = ".*ulauncher.*" },
    decorate = false,
    no_shadow = true,
    no_blur = true,
})
hl.window_rule({ name = "gnome-settings", match = { class = "org.gnome.Settings" }, float = true })
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "steam",
    match = { class = "com.valvesoftware.Steam" },
    float = true,
    center = true,
    size = { 1000, 600 },
})
hl.window_rule({
    name = "steam-windows",
    match = { title = "Steam" },
    float = true,
    size = { 1000, 600 },
})
hl.window_rule({
    name = "steamwebhelper",
    match = { class = "steamwebhelper" },
    float = true,
    size = { 1000, 600 },
})
hl.window_rule({
    name = "pip",
    match = { title = "Picture(-| )in(-| )[Pp]icture" },
    float = true,
    pin = true,
    size = { "25%", "25%" },
    move = { "73%", "72%" },
})
hl.window_rule({
    name = "file-dialogs",
    match = { title = "(Open File|Select a File|Choose wallpaper|Open Folder|Save As|Library|File Upload)(.*)" },
    float = true,
})
hl.window_rule({ name = "steam-app-tearing", match = { class = "steam_app" }, immediate = true })
hl.window_rule({ name = "no-shadow-tiled", match = { float = false }, no_shadow = true })
hl.window_rule({
    name = "skippy-toast",
    match = { title = "skippy-toast" },
    float = true,
    pin = true,
    decorate = false,
    no_shadow = true,
    move = { "100%-372", "40" },
})