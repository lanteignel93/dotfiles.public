-- In your lualine.lua or wherever you configure the plugin
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    -- Colours come from the active theme: it ships lua/lualine/themes/<name>.lua
    -- (picked up by theme = 'auto') and exposes its palette for the tab pin.
    local ok, theme = pcall(require, vim.g.colors_name or 'voidrunner')
    local p = (ok and theme.palette) and theme.palette() or { bg1 = 'NONE', lime = 'NONE' }

    -- (Your other lualine component settings remain the same)
    local mode = {
      'mode',
      fmt = function(str)
        return ' ' .. str
      end,
    }

    local filename = {
      'filename',
      file_status = true,
      path = 0,
    }

    local hide_in_width = function()
      return vim.fn.winwidth(0) > 100
    end

    local diagnostics = {
      'diagnostics',
      sources = { 'nvim_diagnostic' },
      sections = { 'error', 'warn' },
      symbols = { error = ' ', warn = ' ' },
      colored = false,
      cond = hide_in_width,
    }

    local diff = {
      'diff',
      colored = false,
      symbols = { added = ' ', modified = ' ', removed = ' ' },
      cond = hide_in_width,
    }

    -- 4. SETUP LUALINE
    require('lualine').setup {
      options = {
        icons_enabled = true,
        theme = 'auto',
        section_separators = { left = '', right = '' },
        component_separators = { left = '', right = '' },
        disabled_filetypes = { statusline = { 'alpha', 'neo-tree' } },
        always_divide_middle = true,
      },
      sections = {
        lualine_a = { mode },
        lualine_b = { 'branch' },
        lualine_c = { filename },
        lualine_x = { diagnostics, diff, { 'encoding', cond = hide_in_width }, { 'filetype', cond = hide_in_width } },
        lualine_y = { 'location' },
        lualine_z = { 'progress' },
      },
      inactive_sections = {
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { { 'location', padding = 0 } },
      },
      tabline = {
        lualine_a = {
          {
            'buffers',
            -- Pinned: the default inherits mode-section colors, which a
            -- :colorscheme switch (highlight clear) can knock off lime.
            buffers_color = {
              active = { fg = p.bg1, bg = p.lime, gui = 'bold' },
            },
          },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { 'tabs' },
      },
      extensions = { 'fugitive' },
    }
  end,
}
