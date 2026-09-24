-- nvim-treesitter, `main` branch (the rewrite).
-- Migrated from frozen `master` 2026-08-25: the old branch's directive
-- handlers predate nvim 0.10's match-table change and crash on markdown
-- injections (code fences) under nvim 0.12.
-- `main` has no `configs` module: parsers install via
-- require('nvim-treesitter').install(); highlight/indent are started
-- per-buffer with native vim.treesitter. Textobjects moved to that
-- plugin's own `main` API below.
-- NOTE: incremental_selection does not exist on `main` — dropped
-- (old <c-space>/<c-s>/<M-space> maps; revisit if missed).

-- `main` ships NO queries in the plugin: they are installed per language into
-- stdpath('data')/site/queries by install() below. Anything not listed here has
-- no highlights query, so it must not be listed on master-era muscle memory —
-- if you used :TSInstall for it once, add it HERE or it opens unhighlighted.
-- c/cpp/csv/git_config/ini/r/ssh_config were exactly that: ad-hoc :TSInstall
-- parsers that master's bundled queries covered and main's do not (2026-08-25,
-- .hpp files opening as plain text).
local parsers = {
  'bash', 'c', 'cmake', 'cpp', 'csv', 'css', 'cuda', 'dockerfile', 'doxygen',
  'git_config', 'gitignore', 'go', 'graphql', 'groovy', 'html', 'ini', 'java',
  'javascript', 'json', 'latex', 'lua', 'make', 'markdown', 'markdown_inline', 'python',
  'r', 'regex', 'sql', 'ssh_config', 'terraform', 'toml', 'tsx', 'typescript',
  'vim', 'vimdoc', 'yaml',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install(parsers)

      -- Native highlight + treesitter indent wherever a parser exists AND a
      -- highlights query is installed for it.
      --
      -- The query check is not paranoia. vim.treesitter.start() succeeds on any
      -- loadable parser and disables regex syntax as a side effect, so a parser
      -- left over from the master era with no main-era queries renders NOTHING:
      -- the file opens as unhighlighted plain text with a treesitter indentexpr
      -- that has no indents query either. Bailing early keeps regex syntax on,
      -- which is worse than treesitter but far better than blank.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('laurent.treesitter.start', {}),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
          if not lang then
            return
          end
          local ok, query = pcall(vim.treesitter.query.get, lang, 'highlights')
          if not ok or not query then
            return
          end
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Custom filetype associations (unchanged).
      vim.filetype.add { extension = { tf = 'terraform' } }
      vim.filetype.add { extension = { tfvars = 'terraform' } }
      vim.filetype.add { extension = { pipeline = 'groovy' } }
      vim.filetype.add { extension = { multibranch = 'groovy' } }
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    lazy = false,
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup {
        select = { lookahead = true },
        move = { set_jumps = true },
      }

      local sel = require 'nvim-treesitter-textobjects.select'
      local function smap(lhs, query)
        vim.keymap.set({ 'x', 'o' }, lhs, function()
          sel.select_textobject(query, 'textobjects')
        end)
      end
      smap('aa', '@parameter.outer')
      smap('ia', '@parameter.inner')
      smap('af', '@function.outer')
      smap('if', '@function.inner')
      smap('ac', '@class.outer')
      smap('ic', '@class.inner')

      local move = require 'nvim-treesitter-textobjects.move'
      local function mmap(lhs, fn, query)
        vim.keymap.set({ 'n', 'x', 'o' }, lhs, function()
          move[fn](query, 'textobjects')
        end)
      end
      mmap(']m', 'goto_next_start', '@function.outer')
      mmap(']]', 'goto_next_start', '@class.outer')
      mmap(']M', 'goto_next_end', '@function.outer')
      mmap('][', 'goto_next_end', '@class.outer')
      mmap('[m', 'goto_previous_start', '@function.outer')
      mmap('[[', 'goto_previous_start', '@class.outer')
      mmap('[M', 'goto_previous_end', '@function.outer')
      mmap('[]', 'goto_previous_end', '@class.outer')

      local swap = require 'nvim-treesitter-textobjects.swap'
      vim.keymap.set('n', '<leader>a', function()
        swap.swap_next '@parameter.inner'
      end)
      vim.keymap.set('n', '<leader>A', function()
        swap.swap_previous '@parameter.inner'
      end)
    end,
  },

  {
    'hiphish/rainbow-delimiters.nvim',
    config = function()
      require('rainbow-delimiters.setup').setup()
    end,
  },

  {
    'JoosepAlviste/nvim-ts-context-commentstring',
    config = function()
      require('ts_context_commentstring').setup()
      vim.g.skip_ts_context_commentstring_module = true
    end,
  },
}
