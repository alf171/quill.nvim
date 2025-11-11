-- lazy load quill
vim.api.nvim_create_user_command("QuillStart", function()
	require("quill").open_floating_window()
end, {})
