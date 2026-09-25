-- The two themes. Which one loads is decided by ~/.config/theme/current/name,
-- which `dye <name>` writes; both plugins are always installed so a flip needs
-- no :Lazy sync. `dev = true` with lazy's fallback (init.lua) means a box with
-- ~/src/<repo>/main uses that checkout and every other box fetches from GitHub.
local function current()
  local f = io.open(vim.fn.expand("~/.config/theme/current/name"), "r")
  if not f then return "spacecowboy" end
  local name = f:read("*l"); f:close()
  return (name and #name > 0) and name or "spacecowboy"
end

return {
  {
    "lanteignel93/voidrunner.nvim",
    dev = true,
    lazy = false,
    priority = 1000,
    config = function()
      require("voidrunner").setup({ transparent = true })
    end,
  },
  {
    "lanteignel93/spacecowboy.nvim",
    dev = true,
    lazy = false,
    priority = 1000,
    config = function()
      require("spacecowboy").setup({ transparent = true })
      vim.cmd.colorscheme(current())
    end,
  },
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    -- background from the NotifyBackground group the theme sets (bg0)
    opts = {},
  },
}
