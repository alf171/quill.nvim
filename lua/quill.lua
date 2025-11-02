local M = {}

local function create_floating_window(config)
	-- Create a buffer
	local buf = vim.api.nvim_create_buf(false, true)
	-- Create the floating window
	local win = vim.api.nvim_open_win(buf, true, config)

	return { buf = buf, win = win }
end

local create_window_configuration = function()
	--- extra window for the title
	local windows = {
		background = {
			relative = "editor",
			width = vim.o.columns,
			height = vim.o.lines,
			style = "minimal",
			col = 0,
			row = 0,
			zindex = 1,
		},
		header = {
			relative = "editor",
			width = vim.o.columns,
			height = 1,
			style = "minimal",
			border = "rounded",
			col = 0,
			row = 0,
			zindex = 2,
		},
		body = {
			relative = "editor",
			width = vim.o.columns - 10,
			height = vim.o.lines - 5,
			style = "minimal",
			-- border = { "", "", "", "", "", "", "", "" },
			row = 4,
			col = 10,
		},
		--  footer = {
		-- relative = "editor",
		-- width = vim.o.columns,
		-- height = 1,
		-- style = "minimal",
		-- col = 0,
		-- row = 0,
		-- zindex = 2,
		--  }
	}
	return windows
end

-- no config yet
M.setup = function() end

---@class present.Slide
---@field slides present.Slide[]

---@class present.Slide
---@field title string title of the slide
---@field body string body of the side

--- parse some lines
---@param lines string[] lines
---@return present.Slide
local parse_slides = function(lines)
	local slides = { slides = {} }
	local current_slide = {
		title = "",
		body = {},
	}

	local seperator = "^#"

	for _, line in ipairs(lines) do
		if line:find(seperator) then
			if #current_slide.title > 0 then
				table.insert(slides.slides, current_slide)
			end

			current_slide = {
				title = line,
				body = {},
			}
		else
			table.insert(current_slide.body, line)
		end
	end

	table.insert(slides.slides, current_slide)
	return slides
end

local state = {
	current_slide = 1,
	parsed = {},
	floats = {},
}

local foreach_float = function(cb)
	for name, config in pairs(state.floats) do
		cb(name, config)
	end
end

local present_keymap = function(mode, key, callback)
	vim.keymap.set(mode, key, callback, {
		buffer = state.floats.body_float.buf,
	})
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

	state.parsed = parse_slides(lines)

	local windows = create_window_configuration()

	state.floats.bg_float = create_floating_window(windows.background)
	state.floats.header_float = create_floating_window(windows.header)
	state.floats.body_float = create_floating_window(windows.body)

	foreach_float(function(_, float)
		vim.bo[float.buf].filetype = "markdown"
	end)

	local set_slide_content = function(idx)
		local slide = state.parsed.slides[idx]

		local pad = math.floor((vim.o.columns - vim.fn.strdisplaywidth(slide.title)) / 2)
		local padding = string.rep(" ", math.max(pad, 0))
		local title = padding .. slide.title
		vim.api.nvim_buf_set_lines(state.floats.header_float.buf, 0, -1, false, { title })
		vim.api.nvim_buf_set_lines(state.floats.body_float.buf, 0, -1, false, slide.body)
	end

	state.current_slide = 1
	set_slide_content(state.current_slide)

	present_keymap("n", "n", function()
		local current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
		set_slide_content(current_slide)
	end)

	present_keymap("n", "p", function()
		state.current_slide = math.max(state.current_slide - 1, 1)
		set_slide_content(state.current_slide)
	end)

	present_keymap("n", "q", function()
		vim.api.nvim_win_close(state.floats.body_float.win, true)
	end)

	-- modify some user state and restore it
	local restore = {
		cmdheight = {
			original = vim.o.cmdheight,
			present = 0,
		},
	}

	for option, config in pairs(restore) do
		vim.opt[option] = config.present
	end

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = state.floats.body_float.buf,
		callback = function()
			for option, config in pairs(restore) do
				vim.opt[option] = config.original
			end

			pcall(vim.api.nvim_win_close, state.floats.bg_float.win, true)
			pcall(vim.api.nvim_win_close, state.floats.header_float.win, true)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("present-resize", {}),
		callback = function()
			if not vim.api.nvim_win_is_valid(state.floats.body_float.win) then
				return
			end

			local updated = create_window_configuration()
			vim.api.nvim_win_set_config(state.floats.header_float.win, updated.header)
			vim.api.nvim_win_set_config(state.floats.bg_float.win, updated.background)
			vim.api.nvim_win_set_config(state.floats.body_float.win, updated.body)

			set_slide_content(state.current_slide)
		end,
	})
end

M.start_presentation({ file = "tst/buf" })

return M
