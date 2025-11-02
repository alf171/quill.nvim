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
			height = vim.o.columns,
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
			-- border = "rounded",
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
			row = 1,
			col = 10,
		},
		-- footer
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

	local windows = create_window_configuration()

	local bg_float = create_floating_window(windows.background)
	local header_float = create_floating_window(windows.header)
	local body_float = create_floating_window(windows.body)

	vim.bo[header_float.buf].filetype = "markdown"
	vim.bo[body_float.buf].filetype = "markdown"

	local set_slide_content = function(idx)
		local slide = parsed.slides[idx]

		local pad = math.floor((vim.o.columns - vim.fn.strdisplaywidth(slide.title)) / 2)
		local padding = string.rep(" ", math.max(pad, 0))
		local title = padding .. slide.title
		vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { title })
		vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
	end

	local current_slide = 1
	set_slide_content(current_slide)
	vim.keymap.set("n", "n", function()
		current_slide = math.min(current_slide + 1, #parsed.slides)
		set_slide_content(current_slide)
	end, {
		buffer = body_float.buf,
		noremap = true,
		nowait = true,
		silent = true,
	})

	vim.keymap.set("n", "p", function()
		current_slide = math.max(current_slide - 1, 1)
		set_slide_content(current_slide)
	end, {
		buffer = body_float.buf,
		noremap = true,
		nowait = true,
		silent = true,
	})

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(body_float.win, true)
	end, {
		buffer = body_float.buf,
	})

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
		buffer = body_float.buf,
		callback = function()
			for option, config in pairs(restore) do
				vim.opt[option] = config.original
			end

			pcall(vim.api.nvim_win_close, bg_float.win, true)
			pcall(vim.api.nvim_win_close, header_float.win, true)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("present-resize", {}),
		callback = function()
			if not vim.api.nvim_win_is_valid(body_float.win) then
				return
			end

			local updated = create_window_configuration()
			vim.api.nvim_win_set_config(header_float.win, updated.header)
			vim.api.nvim_win_set_config(bg_float.win, updated.background)
			vim.api.nvim_win_set_config(body_float.win, updated.body)

			set_slide_content(current_slide)
		end,
	})
end

M.start_presentation({ file = "tst/buf" })

return M
