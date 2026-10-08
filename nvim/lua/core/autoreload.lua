-- Reload buffers changed on disk by another process (Claude sessions rewriting state files and reports) without
-- needing focus: autoread alone only fires on events, and an unfocused tmux pane gets none. A 1 s stat poll survives
-- atomic rename-on-write, which an fs_event watcher on the file would lose. A buffer with unsaved edits is never
-- clobbered: nvim warns instead.
vim.opt.autoread = true

local group = vim.api.nvim_create_augroup('AutoReload', { clear = true })

local function check()
	local mode = vim.api.nvim_get_mode().mode
	if mode:match('^c') or vim.fn.getcmdwintype() ~= '' then
		return
	end
	vim.cmd('silent! checktime')
end

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'TermLeave' }, {
	group = group,
	callback = check,
})

vim.api.nvim_create_autocmd('FileChangedShellPost', {
	group = group,
	callback = function(ev)
		vim.notify('reloaded ' .. vim.fn.fnamemodify(ev.file, ':~:.'), vim.log.levels.INFO)
	end,
})

local timer = vim.uv.new_timer()
timer:start(1000, 1000, vim.schedule_wrap(check))
