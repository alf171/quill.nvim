local M = {}

M.create_window_configuration = function()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local windows = {
		body = {
			relative = "editor",
			width = width,
			height = height - 1,
			style = "minimal",
			border = "rounded",
			row = row,
			col = col,
			zindex = 1,
		},
		footer = {
			relative = "editor",
			width = width,
			height = 1,
			style = "minimal",
			col = col,
			row = row + height - 1,
			zindex = 2,
		},
	}
	return windows
end

return M
