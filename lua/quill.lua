local M = {}

local function create_floating_window(opts)
	opts = opts or {}
	local width = opts.width or math.floor(vim.o.columns * 0.8)
	local height = opts.height or math.floor(vim.o.lines * 0.8)

	-- get the possible to center of the window
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	-- Create a buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- Define window configuration
	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	-- Create the floating window
	local win = vim.api.nvim_open_win(buf, true, win_config)

	return { buf = buf, win = win }
end

-- no config yet
M.setup = function() end

---@class present.Slides
---@field slides string[]

--- parse some lines
---@param lines string[] lines
---@return present.Slides
local parse_slides = function(lines)
	local slides = { slides = {} }
	local current_slide = {}

	local seperator = "^#"

	for _, line in ipairs(lines) do
		if line:find(seperator) then
			if #current_slide > 0 then
				table.insert(slides.slides, current_slide)
			end

			current_slide = {}
		end

		table.insert(current_slide, line)
	end

	table.insert(slides.slides, current_slide)
	return slides
end

M.start_presentation = function(opts)
	opts = opts or {}

	local lines = {}
	if opts.file then
		local path = vim.fn.expand(opts.file)
		local f = io.open(path, "r")
		if not f then
			vim.notify("Could not open file: " .. path, vim.log.levels.ERROR)
			return
		end

		for line in f:lines() do
			table.insert(lines, line)
		end
		f:close()
	else
		vim.notify("No file provided")
	end

	local parsed = parse_slides(lines)
	local float = create_floating_window()

	local current_slide = 1
	vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
	vim.keymap.set("n", "n", function()
		current_slide = math.min(current_slide + 1, #parsed.slides)
		vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
	end, {
		buffer = float.buf,
	})

	vim.keymap.set("n", "p", function()
		current_slide = math.max(current_slide - 1, 1)
		vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
	end, {
		buffer = float.buf,
	})

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(float.win, true)
	end, {
		buffer = float.buf,
	})
end

M.start_presentation({ file = "tst/buf.tst" })

return M
