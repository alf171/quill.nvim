local M = {}

--- @class quill.Window
--- @field buf integer
--- @field win integer

--- @return quill.Window
M.create_floating_window = function(config, filepath, enter, scratch)
	local listed = not scratch
	local buf

	if scratch then
		buf = vim.api.nvim_create_buf(listed, scratch)
	else
		buf = vim.fn.bufadd(filepath)
		vim.fn.bufload(buf)
	end

	local win = vim.api.nvim_open_win(buf, enter, config)

	if scratch then
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].swapfile = false
		vim.bo[buf].bufhidden = "wipe"
	else
		vim.bo[buf].buftype = ""
		vim.bo[buf].swapfile = false
		vim.bo[buf].bufhidden = "hide"
	end

	vim.bo[buf].buflisted = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "markdown"

	return { buf = buf, win = win }
end

return M
