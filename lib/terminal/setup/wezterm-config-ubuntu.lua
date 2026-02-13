-- WezTerm Configuration
-- Optimized for performance and integration with autocomplete tools

local wezterm = require('wezterm')
local config = {}

-- Inherit default config
config = wezterm.config_builder()

-- Font configuration
config.font = wezterm.font('JetBrains Mono')
config.font_size = 14.0

-- Color scheme (similar to Ghostty light theme)
config.color_scheme = 'Gruvbox Light'

-- Performance optimizations
config.scrollback_lines = 10000

-- Window settings
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

config.initial_cols = 140
config.initial_rows = 40

-- Enable wayland if available
config.enable_wayland = true

-- Hide mouse when typing
config.hide_mouse_cursor_when_typing = true

-- Key bindings (Ctrl+Shift+C/V for copy/paste in terminal style)
local act = wezterm.action
config.keys = {
  -- Copy/Paste
  { key = 'C', mods = 'CTRL|SHIFT', action = act.CopyTo('Clipboard') },
  { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom('Clipboard') },

  -- Scroll
  { key = 'PageUp', mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },

  -- Split panes
  { key = '-', mods = 'CTRL|SHIFT', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
  { key = '=', mods = 'CTRL|SHIFT', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane({ confirm = false }) },
}

-- Tab bar
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false

return config
