-- Monitors
hl.monitor({ output = "eDP-1", mode = "highres", position = "auto", scale = 1 })
hl.monitor({ output = "DSI-1", mode = "highres", position = "auto", scale = 1, transform = 3 })
hl.monitor({ output = "DP-1", mode = "3840x1600@144", position = "2560x1280", scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x2880@60", position = "0x0", scale = 1, transform = 3 })


-- Devices
hl.device({
    name = "goodix-capacitive-touchscreen-1",
    output = "DSI-1",
    transform = 3,
})

-- Core config
hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "colemak",
        kb_options = "caps:backspace",
        numlock_by_default = true,
        kb_rules = "",
        special_fallthrough = true,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.5,
        },
    },

    general = {
        gaps_in = 8,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(ffffffff)", "rgba(000000ff)", "rgba(ffffffff)", "rgba(000000ff)", "rgba(ffffffff)" }, angle = 90 },
            inactive_border = "rgba(414141ff)",
        },
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        dim_special = 0.0,
        active_opacity = 1.0,
        inactive_opacity = 0.8,
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            new_optimizations = true,
            xray = true,
            ignore_opacity = true,
        },
    },

    animations = {
        enabled = true,
    },

    master = {
        allow_small_split = true,
        new_on_top = true,
        orientation = "right",
    },

    dwindle = {
        preserve_split = true,
        smart_split = true,
        smart_resizing = false,
        force_split = 0,
    },

    misc = {
        vrr = 0,
        animate_manual_resizes = true,
        animate_mouse_windowdragging = true,
        enable_swallow = true,
        swallow_regex = "(foot|kitty|allacritty|Alacritty)",
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        initial_workspace_tracking = false,
    },
})

-- Curves
hl.curve("myBezier", { type = "bezier", points = { { 0.0, 0.0 }, { 1.0, 1.0 } } })
hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("md3_decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("md3_accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.13, 0.99 }, { 0.29, 1.1 } } })
hl.curve("crazyshot", { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })
hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1, 0.07 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })
hl.curve("easeOutCirc", { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("softAcDecel", { type = "bezier", points = { { 0.26, 0.26 }, { 0.15, 1 } } })
hl.curve("md2", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })

-- Animations
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 6, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 6, bezier = "overshot", style = "slidefade 80%" })
