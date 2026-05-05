local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

----------------------------------------------------------------
-- 1. Performance
----------------------------------------------------------------
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.max_fps = {{MAX_FPS}}

----------------------------------------------------------------
-- 2. Color Scheme
----------------------------------------------------------------
config.color_scheme = "{{WEZTERM_COLOR_SCHEME}}"

-- Derives tab bar accent colors from the active scheme palette.
local function get_palette()
    local builtins = wezterm.get_builtin_schemes and wezterm.get_builtin_schemes()
    if builtins and builtins[config.color_scheme] then
        return builtins[config.color_scheme]
    end
    -- Generic fallback if scheme lookup fails
    return {
        background = "#1e1e2e",
        foreground = "#cdd6f4",
        ansi    = { "#45475a","#f38ba8","#a6e3a1","#f9e2af","#89b4fa","#cba6f7","#94e2d5","#bac2de" },
        brights = { "#585b70","#f38ba8","#a6e3a1","#f9e2af","#89b4fa","#cba6f7","#94e2d5","#a6adc8" },
    }
end

local palette = get_palette()

----------------------------------------------------------------
-- 3. Visuals
----------------------------------------------------------------
config.win32_system_backdrop = '{{WEZTERM_BACKDROP}}'
config.window_background_opacity = {{WEZTERM_BG_OPACITY}}
config.window_decorations = "RESIZE"

-- Font
config.font = wezterm.font_with_fallback({
    { family = "{{FONT_FAMILY}}", weight = "Regular" },
    { family = "JetBrains Mono" },  -- fallback if chosen font is missing
})
config.font_size = {{FONT_SIZE}}
config.force_reverse_video_cursor = true

----------------------------------------------------------------
-- 4. Tab Bar
----------------------------------------------------------------
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.show_tab_index_in_tab_bar = false

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover)
    local bg = palette.ansi[2]
    local fg = palette.foreground

    if tab.is_active then
        bg = palette.brights[6]
        fg = palette.background
    elseif hover then
        bg = palette.brights[3]
        fg = palette.background
    end

    local title = "  " .. tostring(tab.tab_index + 1) .. "  "
    return {
        { Background = { Color = bg } },
        { Foreground = { Color = fg } },
        { Text = title },
    }
end)

----------------------------------------------------------------
-- 5. Shell & Launch Menu
--
-- Default shell is set by the installer based on your choice.
-- To add more entries, copy one of the commented examples below.
----------------------------------------------------------------
config.default_prog = {{WEZTERM_DEFAULT_SHELL}}

config.launch_menu = {
    { label = "PowerShell 7",  args = { "pwsh.exe" } },
    -- { label = "Arch (WSL)",   args = { "wsl.exe", "--distribution", "Arch", "~" } },
    -- { label = "Ubuntu (WSL)", args = { "wsl.exe", "--distribution", "Ubuntu", "~" } },
    -- { label = "My Server",    args = { "ssh", "user@hostname" } },
}

----------------------------------------------------------------
-- 6. Keybindings
----------------------------------------------------------------
config.disable_default_key_bindings = false
config.leader = { key = "w", mods = "CTRL|SHIFT", timeout_milliseconds = 1000 }

config.keys = {
    -- Clipboard
    { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
    { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
    { key = "t", mods = "CTRL",       action = wezterm.action.ShowLauncher },

    -- Tabs
    { key = "n", mods = "CTRL",       action = act.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = "CTRL",       action = act.CloseCurrentTab({ confirm = true }) },
    { key = "{", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "}", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },

    -- Panes  (leader = Ctrl+Shift+W)
    { key = "x", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "y", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "a", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "d", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
    { key = "w", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "s", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },

    -- Misc
    { key = "r", mods = "CTRL|SHIFT", action = act.ReloadConfiguration },
}

return config
