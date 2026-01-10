local quill_config = require("quill_config")
local quill_helpers = require("quill_helpers")

local default_config = {
	notes_path = "~",
	keymaps = {
		open = "<leader>td",
		close = "q",
		prev = "<C-p>",
		next = "<C-n>",
	},
	debug = false,
}

local M = {
	config = {
		notes_path = nil,
		keymaps = {
			open = nil,
			prev = nil,
			next = nil,
			close = nil,
		},
		debug = nil,
	},
	state = {
		filename = nil,
		full_filename = nil,
		cursor = 0,
		body = {
			win = nil,
			buf = nil,
		},
		footer = {
			win = nil,
			buf = nil,
		},
	},
}

local init = function(opts)
	M.config = opts or default_config
end

--- debug print only prints if the debug field in config is set
--- @param message string: the message to print
local debug_print = function(message)
	if M.config.debug then
		print(message)
	end
end

local setup_notes_file = function()
	local date = os.date("%Y-%m-%d")
	local expanded_notes_path = vim.fn.expand(M.config.notes_path)

	M.filename = "quill_" .. date .. ".txt"
	M.full_filename = expanded_notes_path .. M.filename

	if vim.fn.filereadable(M.full_filename) ~= 1 then
		local file, err = io.open(M.full_filename, "w")

		if file then
			file:write("")
			file:close()
			debug_print("Created successfully!")
		else
			print("error creating quill notes file: ", err)
		end
	end
end

--- @param days number: number of days to go forward if positive of backward if negative
--- @return { filename: string, full_filename: string } | nil: return yesterday's notes if they exist. Otherwise, nil
M.get_other_notes = function(days)
	-- Assume M.filename = "quill_2025-11-09.txt"
	local date_str = M.filename:match("quill_(%d%d%d%d%-%d%d%-%d%d)%.txt")
	if not date_str then
		error("Invalid filename format: " .. M.filename)
	end

	local year, month, day = date_str:match("(%d+)%-(%d+)%-(%d+)")
	local current_time = os.time({
		year = year,
		month = month,
		day = day,
	})
	local prev_time = current_time + (24 * 60 * 60 * days)
	local prev_date = os.date("%Y-%m-%d", prev_time)

	local prev_filename = "quill_" .. prev_date .. ".txt"
	local prev_full_filename = vim.fn.expand(M.config.notes_path) .. prev_filename

	if vim.fn.filereadable(prev_full_filename) == 1 then
		return { filename = prev_filename, full_filename = prev_full_filename }
	end

	return nil
end

local place_todays_quote = function()
	local file = io.open(M.full_filename, "r+")
	if file == nil then
		print("error fetching file when placing quote")
		return
	end
	local line = file:read("*l")
	if line and line:match("^#") then
		file:close()
		return
	end
	local json = vim.fn.system("curl -s https://zenquotes.io/api/random")
	local ok, decoded = pcall(vim.fn.json_decode, json)
	local quote = nil
	local author = nil
	if ok then
		quote = decoded[1].q
		author = decoded[1].a
	else
		print("error fetching quote")
		file:close()
		return
	end
	file:seek("set", 0)
	file:write("# " .. quote .. " [" .. author .. "]")
	debug_print("writing quote to file")
	file:flush()
	file:close()
end

---@param footer_config table the configuration to load the footer with
---@param type '"UPDATE"'|'"CREATE"' the type of footer action to perform
local render_footer = function(footer_config, type)
	if type == "CREATE" then
		local footer = quill_helpers.create_floating_window(footer_config, M.full_filename, false, true)
		M.state.footer = footer
	end
	local footer_content = M.filename .. " [" .. M.state.cursor .. "]"
	vim.api.nvim_buf_set_lines(M.state.footer.buf, 0, -1, false, { footer_content })
end

M.open_floating_window = function()
	if M.state.body.buf ~= nil then
		debug_print("avoid reopening already open floating window")
		return
	end

	local windows = quill_config.create_window_configuration()
	local body = quill_helpers.create_floating_window(windows.body, M.full_filename, true, false)
	M.state.body = body

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = body.buf,
		once = true,
		callback = function()
			M.state.body.win = nil
			M.state.body.buf = nil
			M.state.footer.win = nil
			M.state.footer.buf = nil
		end,
	})

	render_footer(windows.footer, "CREATE")
	M.set_local_commands()
end

local open_floating_window_cmd = function()
	vim.keymap.set("n", M.config.keymaps.open, function()
		M.open_floating_window()
	end, { buffer = M.state.body.buf, nowait = true })
end

M.set_local_commands = function()
	vim.keymap.set("n", M.config.keymaps.next, function()
		M.state.cursor = M.state.cursor + 1
		local other_notes = M.get_other_notes(M.state.cursor)
		if other_notes == nil then
			debug_print("forward notes don't exist!")
			render_footer(quill_config.create_window_configuration().footer, "UPDATE")
			return
		else
			M.state.cursor = 0
		end
		M.filename = other_notes.filename
		M.full_filename = other_notes.full_filename
		M.cleanup()
		M.open_floating_window()
	end, {
		buffer = M.state.body.buf,
		silent = true,
	})

	vim.keymap.set("n", M.config.keymaps.prev, function()
		M.state.cursor = M.state.cursor - 1
		local other_notes = M.get_other_notes(M.state.cursor)
		if other_notes == nil then
			debug_print("backward notes don't exist!")
			render_footer(quill_config.create_window_configuration().footer, "UPDATE")
			return
		else
			M.state.cursor = 0
		end
		M.filename = other_notes.filename
		M.full_filename = other_notes.full_filename
		M.cleanup()
		M.open_floating_window()
	end, {
		buffer = M.state.body.buf,
		silent = true,
	})

	vim.keymap.set("n", M.config.keymaps.close, function()
		M.cleanup()
	end)
end

M.cleanup = function()
	debug_print("attempting a cleanup")
	-- close the window
	if M.state.body.win and vim.api.nvim_win_is_valid(M.state.body.win) then
		vim.api.nvim_win_close(M.state.body.win, true)
	end
	if M.state.footer.win and vim.api.nvim_win_is_valid(M.state.footer.win) then
		vim.api.nvim_win_close(M.state.footer.win, true)
	end
	--
	-- -- close the buffer
	-- if M.state.body.buf and vim.api.nvim_buf_is_valid(M.state.body.buf) then
	-- 	vim.api.nvim_buf_delete(M.state.body.buf, { force = true })
	-- end
	--
	-- if M.state.footer.buf and vim.api.nvim_buf_is_valid(M.state.footer.buf) then
	-- 	vim.api.nvim_buf_delete(M.state.footer.buf, { force = true })
	-- end
end

local setup_autocommands = function()
	-- resize windows on terminal resizing
	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("quill-resize", {}),
		callback = function()
			if not vim.api.nvim_win_is_valid(M.state.body.win) then
				return
			end

			local updated = quill_config.create_window_configuration()
			vim.api.nvim_win_set_config(M.state.body.win, updated.body)
			vim.api.nvim_win_set_config(M.state.footer.win, updated.footer)
		end,
	})

	-- close footer when body is closed
	vim.api.nvim_create_autocmd({ "WinClosed" }, {
		callback = function(args)
			local closed_win = tonumber(args.match)
			if closed_win == M.state.body.win then
				local footer_window = M.state.footer.win
				if vim.api.nvim_win_is_valid(footer_window) then
					vim.api.nvim_win_close(footer_window, true)
				end
			end
		end,
	})
end

-- TODO: add an oil.nvim like view of notes -- maybe even some higher order notes management?
-- TODO: render file in markdown (external plugin?)

M.setup = function(opts)
	init(opts)
	setup_notes_file()
	place_todays_quote()
	open_floating_window_cmd()
	setup_autocommands()
end

return M
