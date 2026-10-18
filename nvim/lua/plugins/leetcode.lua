return {
    "kawre/leetcode.nvim",
    -- cmd = "Leet",
    build = ":TSUpdate html", -- Recommended if you have nvim-treesitter
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    -- This runs *before* the plugin loads, good for autocommands
    init = function()
        -- Autocmd for LeetCode buffers
        vim.api.nvim_create_autocmd("FileType", {
            pattern = { "leetcode", "leetcode_desc" }, -- Adjust once you check :set ft
            callback = function()
                -- Disable Treesitter
                pcall(vim.treesitter.stop, 0)

                -- Disable diagnostics in LC buffers
                pcall(vim.diagnostic.disable, 0)

                -- Optional: keep buffers lightweight
                vim.opt_local.swapfile = false
            end,
        })
    end,
    opts = {
        -- This sets the default language when you open the plugin
        lang = "cpp",

        ui = {
            -- Try a minimal theme if available
            theme = "minimal",      -- or "dark", "light" depending on plugin support
            code = {
                position = "right", -- or "split", "tab", etc. (simpler layout can feel faster)
            },
            console = {
                position = "bottom", -- "float" can be nice but sometimes heavier
            },
        },
    },
    -- C++ style: LeetCode solutions follow dotclaude's house style, like every
    -- other C++ project. leetcode.nvim has no format option; clang-format (conform,
    -- on demand) walks up from the solution file to the storage dir's .clang-format,
    -- so that file is kept a link to dotclaude's copy. Only a link is ever replaced,
    -- never a real file. The dir's .clangd is hand-made (it pre-includes the
    -- prelude header) and is left alone.
    -- Indent as you type: vim-sleuth guesses shiftwidth from each file, and the
    -- older solutions predate the house style (2-space), so <CR>/<Tab> indented by
    -- 2 and kept it even after <leader>f. The dir's .editorconfig declares 4, which
    -- sleuth (and nvim's own editorconfig) take over the guess. Written once if
    -- missing, never overwritten.
    config = function(_, opts)
        require("leetcode").setup(opts)
        local home = vim.fn.stdpath("data") .. "/leetcode"
        local editorconfig = home .. "/.editorconfig"
        if not vim.uv.fs_lstat(editorconfig) then
            vim.fn.mkdir(home, "p")
            vim.fn.writefile({ "root = true", "", "[*]", "indent_style = space", "indent_size = 4" }, editorconfig)
        end
        for _, dir in ipairs({ vim.env.DOTCLAUDE_DIR or "", "~/dotclaude", "~/git_projects/dotclaude" }) do
            local style = vim.fn.expand(dir .. "/dev-tool-box/cpp/clang-format")
            if dir ~= "" and vim.uv.fs_stat(style) then
                local link = home .. "/.clang-format"
                local current = vim.uv.fs_readlink(link)
                if current ~= style and (current or not vim.uv.fs_lstat(link)) then
                    vim.fn.mkdir(home, "p")
                    if current then vim.uv.fs_unlink(link) end
                    vim.uv.fs_symlink(style, link)
                end
                return
            end
        end
    end,
}
