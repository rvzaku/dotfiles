local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"

-- WezTerm bundles JetBrains Mono. Keeping a single configured family avoids
-- host-specific font installation and family-name mismatches.
config.font = wezterm.font("JetBrains Mono")
config.font_size = 15.0
config.line_height = 1.0

config.window_background_opacity = 0.80
config.macos_window_background_blur = 50
config.window_decorations = "RESIZE"

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true

config.enable_scroll_bar = false
config.scrollback_lines = 10000
config.adjust_window_size_when_changing_font_size = false
config.native_macos_fullscreen_mode = true
config.quit_when_all_windows_are_closed = false

config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 650
config.animation_fps = 60
config.max_fps = 120

config.keys = {
  {
    key = "Enter",
    mods = "CMD",
    action = wezterm.action.ToggleFullScreen,
  },
  {
    key = "k",
    mods = "CMD",
    action = wezterm.action.ClearScrollback("ScrollbackAndViewport"),
  },
}

return config
