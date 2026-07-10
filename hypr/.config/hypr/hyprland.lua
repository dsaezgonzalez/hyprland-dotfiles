-- Hyprland Lua Configuration for Diego
-- Migrated from legacy hyprland.conf to support Hyprland v0.55+

------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "DP-1",
    mode     = "2560x1440@180",
    position = "0x0",
    scale    = 1,
})

---------------------
---- MY PROGRAMS ----
---------------------
local mainMod                       = "SUPER"
local terminal                      = "kitty"
local fileManager                   = "kitty -e yazi"
local menu                          = "rofi -show drun"
local screenshotRegionClipboard     = "hyprshot -m region --clipboard-only -z -s"
local screenshotActiveClipboard     = "hyprshot -m window --clipboard-only -z -s"
local screenshotOutputClipboard     = "hyprshot -m output --clipboard-only -z -s"
local screenshotRegion              = "hyprshot -m region -o ~/Pictures/Images/ -z -s"
local screenshotActive              = "hyprshot -m window -o ~/Pictures/Images/ -z -s"
local screenshotOutput              = "hyprshot -m output -o ~/Pictures/Images/ -z -s"
local antigravityCLI                = "kitty -e agy"

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("/home/diego/.config/quickshell/launch.sh")
    hl.exec_cmd("bash -c 'kitty --class dropdown-terminal >/dev/null 2>&1 & sleep 0.5 && hyprctl dispatch \"hl.dsp.window.resize({ x = 1000, y = 400, window = \\\"class:^(dropdown-terminal)$\\\" })\" && hyprctl dispatch \"hl.dsp.window.move({ x = 10, y = 58, window = \\\"class:^(dropdown-terminal)$\\\" })\"'")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("GTK_THEME", "Adwaita:dark")

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = "rgb(7197CB)",
            inactive_border = "rgb(9FD0DD)",
        },
        layout = "dwindle",
    },
    decoration = {
        rounding       = 14,
        rounding_power = 2,
        
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        blur = {
            enabled        = true,
            size           = 9,
            passes         = 3,
            ignore_opacity = true,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    }
})

-- Default Curves and Animations for smooth aesthetics
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 5,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 2.5,  bezier = "linear",       style = "slide" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 3.2,  bezier = "almostLinear", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.2, bezier = "almostLinear", style = "slidefadevert -100%" })

---------------------
---- KEYBINDINGS ----
---------------------

-- Shortcuts
hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("/home/diego/.config/quickshell/launch.sh"))
hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd("quickshell ipc call clipboard toggle"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("quickshell ipc call theme toggle"))
hl.bind(mainMod .. " + TAB",       hl.dsp.exec_cmd(antigravityCLI))

-- Media and Volume Controls (Hardware Agnostic)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Dropdown Terminal
hl.bind(mainMod .. " + RETURN", hl.dsp.workspace.toggle_special("terminal"))

-- Music Scratchpad (PWA)
hl.bind(mainMod .. " + M", hl.dsp.workspace.toggle_special("music"))


-- Move focus
hl.bind(mainMod .. " + H",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L",  hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K",  hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J",  hl.dsp.focus({ direction = "down" }))

-- Move windows around
hl.bind(mainMod .. " + SHIFT + H",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L",  hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K",  hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J",  hl.dsp.window.move({ direction = "down" }))

-- Resize windows (Keyboard)
hl.bind(mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
hl.bind(mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
hl.bind(mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
hl.bind(mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 20, relative = true }))

-- Switch workspaces and move windows to them
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "+1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshotRegionClipboard))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(screenshotOutputClipboard))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(screenshotActiveClipboard))
hl.bind("ALT + SHIFT + S",         hl.dsp.exec_cmd(screenshotRegion))
hl.bind("ALT + SHIFT + A",         hl.dsp.exec_cmd(screenshotOutput))
hl.bind("ALT + SHIFT + W",         hl.dsp.exec_cmd(screenshotActive))

--------------------------
---- WINDOW RULES ----
--------------------------
hl.window_rule({
    name    = "nemo-opacity-override",
    match   = { class = "(?i)nemo" },
    opacity = "1.0 override 1.0 override",
})

hl.window_rule({
    name      = "apple-music-scratchpad",
    match     = { class = "(?i)sidra" },
    workspace = "special:music",
    float     = true,
    size      = "70% 75%",
    center    = true,
})

hl.window_rule({
    name      = "dropdown-terminal",
    match     = { class = "(?i)dropdown-terminal" },
    workspace = "special:terminal",
    float     = true,
    size      = "40% 40%",
    center    = true,
})