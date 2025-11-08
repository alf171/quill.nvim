local quill_config = require("quill_config")

-- TODO: these should be defaults an config should be hoisted into dotfiles
-- TODO: consider setting M as first param and using M:
local M = {
	config = {
		notes_path = "~/Desktop/notes/",
		keymaps = {
			open = "<leader>td",
			close = "q",
			previous = "<C-p>",
			next = "<C-n>",
		},
	},
	state = {
		filename = nil,
		full_filename = nil,
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

-- M.setup = function(opts)
-- 	opts = opts or {}
-- end

M.setup_notes_file = function()
	local date = os.date("%Y-%m-%d")
	local expanded_notes_path = vim.fn.expand(M.config.notes_path)

	M.filename = "quill_" .. date .. ".txt"
	M.full_filename = expanded_notes_path .. M.filename

	if not vim.fn.filereadable(M.full_filename) == 1 then
		local file = io.open(M.full_filename, "w")

		if file then
			file:write("")
			file:close()
			print("Created successfully!")
		else
			print("error creating quill notes file")
		end
	end
end

M.place_todays_quote = function()
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
	file:write("# " .. quote .. " [" .. author .. "]")
	print("writing quote to file")
	file:flush()
	file:close()
end

--- @class quill.Window
--- @field buf integer
--- @field win integer

--- @return quill.Window
local create_floating_window = function(config, filepath, enter)
	if enter == nil then
		enter = true
	end

	local buf = vim.api.nvim_create_buf(true, true)

	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent edit " .. vim.fn.fnameescape(filepath))
	end)

	local win = vim.api.nvim_open_win(buf, enter, config)

	vim.bo[buf].modifiable = true
	vim.bo[buf].buftype = ""
	vim.bo[buf].buflisted = true
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = true
	vim.bo[buf].filetype = "markdown"

	return { buf = buf, win = win }
end

-- TODO: closing footer
M.open_floating_window = function()
	local windows = quill_config.create_window_configuration()
	vim.keymap.set("n", M.config.keymaps.open, function()
		local body = create_floating_window(windows.body, M.full_filename)
		M.state.body.buf = body.buf
		M.state.body.win = body.win
		-- TODO: footer should be a scratch buffer unlike body
		-- TODO: footer also shouldn't get focused -- pull out some props of creat floating a set on call :)
		local footer = create_floating_window(windows.footer, M.full_filename)
		M.state.footer.buf = footer.buf
		M.state.footer.win = footer.win
		vim.api.nvim_buf_set_lines(M.state.footer.buf, 0, -1, false, { M.filename })
	end)
end

-- TODO: antoher autocommand. This one will listen to see if body is closed
-- If so, close footer along with it
M.setup_autocommands = function()
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
	-- vim.api.nvim_create_autocmd("quill-resize", {})
end

-- TODO: add support for going forward and backward in todays notes
-- TODO: render file in markdown (external plugin?)

M.setup_notes_file()
M.place_todays_quote()
M.open_floating_window()
M.setup_autocommands()

return M
