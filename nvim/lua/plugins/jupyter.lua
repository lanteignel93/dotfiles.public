-- Jupyter notebooks inside nvim. Three pieces that only make sense together:
--
--   jupytext.nvim  opens an .ipynb as MARKDOWN and writes it back as a
--                  notebook on :w. Needs the `jupytext` CLI; without it you
--                  get raw JSON.
--   otter.nvim     LSP/completion inside the ```python blocks only.
--   molten-nvim    runs cells against a real Jupyter kernel and shows the
--                  output. Needs `pynvim` + `jupyter_client` in the python
--                  nvim itself uses (not the project venv).
--   snacks.nvim    inline plots (its image module; snacks is configured in
--                  plugins/snacks.lua). Used ONLY where they can render.
--
-- On images: the terminal you are sitting at has to speak the kitty graphics
-- protocol -- kitty or Ghostty in full, WezTerm only as a fallback overlay. True
-- on the desktop, and on any box ssh'd into from it; false on the Windows work
-- laptop (Alacritty has neither the kitty protocol nor stable sixel). Rather
-- than erroring there, molten falls back to text output and everything else
-- still works. Not WezTerm on Windows: its kitty images do not survive ssh there
-- (wezterm#5757). The Windows plan is real kitty under WSLg.
--
-- Why snacks and not image.nvim (which this used until 2026-09-23): image.nvim
-- paints the plot as an overlay at screen coordinates it works out itself.
-- Nothing else knows the overlay is there -- not tmux (switch window and the
-- plot stays burned over whatever is now on screen), and not molten, whose
-- `Out[n]: Done` + text lines sit in the same spot image.nvim draws at, so the
-- plot covered them. snacks writes the plot INTO the buffer as kitty unicode
-- placeholders inside a virt_lines extmark: nvim lays it out like any other
-- line, tmux stores it like any other cell. Scrolling, splits, window and
-- session switches all just work, because nobody is chasing coordinates.
--
-- Why markdown and not `# %%` python cells: a research notebook is mostly
-- prose. As python, every markdown cell arrives as a comment (raw `|---|`
-- tables, `# ###` headings) AND ruff/basedpyright lint the English — E501 on
-- every sentence, E402 on every import that follows prose. As markdown,
-- markview renders the prose, the python LSPs never attach to the buffer, and
-- otter gives the code blocks their own LSP.
--
-- Keymaps hang off <leader>j (j = jupyter), a prefix nothing else uses.
--
-- Requirements, once per machine (bootstrap.sh does all of this):
--   pip install --user pynvim jupyter_client jupytext ipykernel matplotlib
--   python3 -m ipykernel install --user --name python3   <- easy to forget; without
--                                                          a registered kernelspec
--                                                          MoltenInit has nothing to
--                                                          attach to
--
-- Gotcha: jupytext.nvim throws on a notebook whose metadata has no kernelspec
-- (anything produced by a bare `jupytext --to ipynb`, most generated ones). This
-- file used to say "fix the file" (jupytext --set-kernel python3 nb.ipynb); a
-- whole folder of them on prd3 made that untenable, so the jupytext spec below
-- now guards the plugin instead.

-- The terminal that will actually draw the plot is the one at the far end,
-- not anything in between. Over ssh none of KITTY_WINDOW_ID / GHOSTTY_BIN_DIR /
-- TERM_PROGRAM arrive (ssh forwards TERM and nothing else), and inside tmux TERM
-- is tmux's own. tmux still records each attached client's terminal, and on a
-- remote box that is the TERM ssh passed along: xterm-kitty when you came in
-- from kitty. Checking only the env vars is what switched plots off on work
-- boxes reached from the desktop.
local function outer_term()
	if vim.env.TMUX then
		local out = vim.fn.system({ 'tmux', 'display-message', '-p', '#{client_termname}' })
		if vim.v.shell_error == 0 and vim.trim(out) ~= '' then
			return vim.trim(out)
		end
	end
	return vim.env.TERM or ''
end

-- No ImageMagick requirement: plots arrive as PNG, and snacks reads PNG itself
-- (it only shells out to `magick` to convert other formats).
local function graphics_available()
	if vim.env.KITTY_WINDOW_ID or vim.env.GHOSTTY_BIN_DIR or vim.env.TERM_PROGRAM == 'WezTerm' then
		return true
	end
	local term = outer_term()
	for _, name in ipairs({ 'kitty', 'ghostty', 'wezterm' }) do
		if term:find(name, 1, true) then
			return true
		end
	end
	return false
end

-- Find every ```python block in the buffer, as {from, to} line ranges of the
-- body. Fences in other languages are skipped rather than sent to the kernel.
local function code_blocks()
	local blocks, open, is_python = {}, nil, false
	for lnum = 1, vim.fn.line('$') do
		local line = vim.fn.getline(lnum)
		if open then
			if line:match('^```') then
				if is_python and lnum - 1 >= open then
					blocks[#blocks + 1] = { from = open, to = lnum - 1 }
				end
				open = nil
			end
		else
			local lang = line:match('^```%s*{?(%a*)')
			if lang then
				open, is_python = lnum + 1, (lang == 'python' or lang == 'py')
			end
		end
	end
	return blocks
end

-- Molten has no range command: select the body, leave visual mode (which sets
-- the '< '> marks it reads), then hand it over. Evaluations queue on the
-- kernel in the order they are sent.
local function eval_range(from, to)
	local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
	vim.cmd(('normal! %dGV%dG%s'):format(from, to, esc))
	vim.cmd('MoltenEvaluateVisual')
end

local function evaluate_cell()
	local cursor = vim.fn.line('.')
	for _, b in ipairs(code_blocks()) do
		if cursor >= b.from - 1 and cursor <= b.to + 1 then
			return eval_range(b.from, b.to)
		end
	end
	vim.notify('molten: cursor is not in a python cell', vim.log.levels.WARN)
end

-- `upto` limits to cells at or above the cursor, which is the usual way back
-- after a restart: rebuild state without re-running the expensive tail.
local function evaluate_all(upto)
	local cursor = vim.fn.line('.')
	local saved = vim.api.nvim_win_get_cursor(0)
	local count = 0
	for _, b in ipairs(code_blocks()) do
		if not upto or b.from - 1 <= cursor then
			eval_range(b.from, b.to)
			count = count + 1
		end
	end
	pcall(vim.api.nvim_win_set_cursor, 0, saved)
	vim.notify(('molten: queued %d cell%s'):format(count, count == 1 and '' or 's'))
end

-- Which python the notebook's code runs in. molten itself always runs on the
-- global python3 (pynvim + jupyter_client, --user); the KERNEL is what has to
-- be the project's venv, so imports see the project's packages. Order: the venv
-- you activated before starting nvim, else the nearest .venv/venv above the
-- notebook, else the global python3 kernel.
local function project_venv()
	local active = vim.env.VIRTUAL_ENV
	if active and vim.fn.executable(active .. '/bin/python') == 1 then
		return active
	end
	local found = vim.fs.find({ '.venv', 'venv' }, {
		path = vim.fn.expand('%:p:h'),
		upward = true,
		type = 'directory',
		stop = vim.env.HOME,
	})[1]
	if found and vim.fn.executable(found .. '/bin/python') == 1 then
		return found
	end
end

-- A kernelspec per venv. molten's docs name it after the venv directory, but
-- with uv every project's venv IS `.venv`, so they would all collide: name it
-- after the project directory and disambiguate with a hash of the venv path.
local function venv_kernel(venv)
	local base = vim.fs.basename(venv)
	local project = (base == '.venv' or base == 'venv') and vim.fs.basename(vim.fs.dirname(venv)) or base
	local name = ('venv-%s-%s'):format(project:lower():gsub('[^%w%.%-_]', '-'), vim.fn.sha256(venv):sub(1, 8))
	return name, project
end

-- molten starts the kernel, then writes a second copy of its connection file
-- to <jupyter data>/runtime/ WITHOUT creating that directory. On a box where
-- Jupyter never ran it does not exist, and every MoltenInit dies with ENOENT on
-- runtime/kernel-<id>.json (a work box, 2026-09-23). bootstrap.sh creates it
-- too; this covers boxes and cleanups bootstrap never saw.
local function jupyter_data_dir()
	local data = vim.env.JUPYTER_DATA_DIR or vim.fn.expand('~/.local/share/jupyter')
	vim.fn.mkdir(data .. '/runtime', 'p', 448) -- 448 = 0700
	return data
end

local function init_kernel()
	jupyter_data_dir()
	local venv = project_venv()
	if not venv then
		return vim.cmd('MoltenInit python3')
	end
	local python = venv .. '/bin/python'
	local name, project = venv_kernel(venv)
	local where = vim.fn.fnamemodify(venv, ':~')

	local function start()
		if vim.fn.filereadable(jupyter_data_dir() .. '/kernels/' .. name .. '/kernel.json') == 0 then
			local res = vim.system({
				python, '-m', 'ipykernel', 'install', '--user',
				'--name', name, '--display-name', ('%s (%s)'):format(project, where),
			}, { text = true }):wait()
			if res.code ~= 0 then
				return vim.notify(('molten: could not register a kernel for %s\n%s'):format(where, res.stderr), vim.log.levels.ERROR)
			end
		end
		vim.notify(('molten: %s kernel (%s)'):format(project, where))
		vim.cmd('MoltenInit ' .. name)
	end

	if vim.system({ python, '-c', 'import ipykernel' }):wait().code == 0 then
		return start()
	end
	-- Installing into a project env is the user's call, so ask. uv first: venvs
	-- made by uv have no pip at all.
	if vim.fn.confirm(('%s has no ipykernel. Install it there?'):format(where), '&Yes\n&No', 1) ~= 1 then
		return vim.notify('molten: no kernel started', vim.log.levels.WARN)
	end
	local cmd = vim.fn.executable('uv') == 1 and { 'uv', 'pip', 'install', '--python', python, 'ipykernel' }
		or { python, '-m', 'pip', 'install', 'ipykernel' }
	vim.notify(('molten: installing ipykernel into %s ...'):format(where))
	vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
		if res.code ~= 0 then
			return vim.notify('molten: ipykernel install failed\n' .. (res.stderr or ''), vim.log.levels.ERROR)
		end
		start()
	end))
end

return {
	{
		'GCBallesteros/jupytext.nvim',
		lazy = false, -- has to be loaded before an .ipynb is opened
		opts = {
			style = 'markdown',
			output_extension = 'md',
			force_ft = 'markdown', -- markview renders markdown by default; quarto it does not
		},
		config = function(_, opts)
			require('jupytext').setup(opts)
			-- jupytext.nvim reads metadata.kernelspec.language unguarded, so a notebook
			-- without a kernelspec throws inside BufReadCmd and you get an EMPTY buffer.
			-- Generated notebooks look like that (every slalom notebook on prd3 did).
			-- Fall back to the notebook's language_info, then python. The file is not
			-- touched; the kernel is picked by <leader>ji, not by this metadata.
			local utils = require('jupytext.utils')
			local original = utils.get_ipynb_metadata
			local extensions = { python = 'py', julia = 'jl', r = 'r', R = 'r', bash = 'sh' }
			utils.get_ipynb_metadata = function(filename)
				local ok, result = pcall(original, filename)
				if ok then
					return result
				end
				local language = 'python'
				local f = io.open(filename, 'r')
				if f then
					local decoded, nb = pcall(vim.json.decode, f:read('a'))
					f:close()
					local info = decoded and type(nb) == 'table' and type(nb.metadata) == 'table' and nb.metadata.language_info
					if type(info) == 'table' and type(info.name) == 'string' then
						language = info.name
					end
				end
				return { language = language, extension = extensions[language] or 'py' }
			end
		end,
	},

	{
		'benlubas/molten-nvim',
		-- Track main, not a tag: the snacks image provider (#299, #318) landed
		-- after v1.9.2, the last tag, so `version = '^1.0.0'` can never reach it.
		-- lazy-lock.json still pins the exact commit.
		version = false,
		build = ':UpdateRemotePlugins',
		dependencies = { 'folke/snacks.nvim' },
		init = function()
			-- molten runs in nvim's python3 host, which needs pynvim + jupyter_client:
			-- the system python3 has them (--user). Left to itself nvim takes the first
			-- python3 on PATH, and an activated venv puts ITS python3 there -- on prd3
			-- onepipeline/venv (3.10, no pynvim) gave "Failed to load python3 host".
			-- The project venv is the KERNEL's job (init_kernel), never the host's.
			if vim.fn.executable('/usr/bin/python3') == 1 then
				vim.g.python3_host_prog = '/usr/bin/python3'
			end
			-- Must be set before the remote plugin loads.
			vim.g.molten_image_provider = graphics_available() and 'snacks.nvim' or 'none'
			vim.g.molten_virt_text_output = true -- output as virtual text under the cell
			vim.g.molten_auto_open_output = false -- ...so don't also pop a float
			vim.g.molten_wrap_output = true
			vim.g.molten_output_win_max_height = 20
			-- Images under the cell only. The default is "both", which draws the same
			-- plot a second time in the float we never open.
			vim.g.molten_image_location = 'virt'
			-- Caps the TEXT lines of the output block (default 12). The plot is not
			-- counted here: it is its own extmark, sized by snacks' image.doc
			-- max_width/max_height in plugins/snacks.lua.
			vim.g.molten_virt_text_max_lines = 30
			-- jupytext opens .ipynb as markdown, so the line the output block covers
			-- is just the closing ``` -- let it, instead of pushing everything down.
			vim.g.molten_virt_lines_off_by_1 = true
		end,
		keys = {
			{ '<leader>ji', init_kernel, desc = 'Jupyter: init kernel (project venv, else python3)' },
			{
				'<leader>jI',
				function()
					jupyter_data_dir()
					vim.cmd('MoltenInit')
				end,
				desc = 'Jupyter: init kernel (pick from list)',
			},
			{ '<leader>jc', evaluate_cell, desc = 'Jupyter: run cell' },
			{ '<leader>ja', function() evaluate_all(false) end, desc = 'Jupyter: run all cells' },
			{ '<leader>jA', function() evaluate_all(true) end, desc = 'Jupyter: run cells above (incl. current)' },
			{ '<leader>jl', '<cmd>MoltenEvaluateLine<cr>', desc = 'Jupyter: run line' },
			{ '<leader>jr', '<cmd>MoltenReevaluateCell<cr>', desc = 'Jupyter: re-run cell' },
			{ '<leader>jv', ':<C-u>MoltenEvaluateVisual<cr>gv', mode = 'v', desc = 'Jupyter: run selection' },
			{ '<leader>jo', '<cmd>MoltenShowOutput<cr>', desc = 'Jupyter: show output' },
			{ '<leader>jh', '<cmd>MoltenHideOutput<cr>', desc = 'Jupyter: hide output' },
			{ '<leader>je', '<cmd>MoltenEnterOutput<cr>', desc = 'Jupyter: enter output window' },
			{ '<leader>jn', '<cmd>MoltenNext<cr>', desc = 'Jupyter: next cell' },
			{ '<leader>jp', '<cmd>MoltenPrev<cr>', desc = 'Jupyter: previous cell' },
			{ '<leader>jx', '<cmd>MoltenInterrupt<cr>', desc = 'Jupyter: interrupt' },
			{ '<leader>jR', '<cmd>MoltenRestart<cr>', desc = 'Jupyter: restart kernel' },
			{ '<leader>jd', '<cmd>MoltenDelete<cr>', desc = 'Jupyter: delete cell' },
		},
	},

	{
		-- LSP inside the code blocks. It builds a hidden python buffer from the
		-- ```python chunks, so completion and diagnostics follow the code and
		-- leave the prose alone.
		'jmbuhr/otter.nvim',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
		lazy = false,
		config = function()
			-- Hook FileType, not BufReadPost: jupytext reads the notebook through a
			-- BufReadCmd autocmd, and BufReadCmd suppresses BufReadPost entirely, so
			-- a BufReadPost hook never fires for an .ipynb.
			vim.api.nvim_create_autocmd('FileType', {
				pattern = 'markdown',
				callback = function(args)
					if vim.api.nvim_buf_get_name(args.buf):match('%.ipynb$') then
						pcall(function() require('otter').activate({ 'python' }) end)
						-- Typeset the markdown cells' LaTeX ($...$, $$...$$) as images.
						-- snacks' doc renderer is off globally (plugins/snacks.lua), so
						-- plain markdown notes are untouched; notebooks opt in here.
						-- Needs the `latex` treesitter parser, a TeX engine (pdflatex or
						-- tectonic) and ghostscript for magick's PDF -> PNG step.
						if graphics_available() then
							pcall(function() Snacks.image.doc.attach(args.buf) end)
						end
					end
				end,
			})
		end,
	},
}
