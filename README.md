# `quill.nvim`

todo list plugin.

Once per day, a file is generated with a quote and persisted in a dir of choice.

# Credit

following teej_dv advent of neovim writing a plugin as a starting point

# Commands

- Open notes with <leader>td
- Cycle between previous notes and tomorrows notes with <C-p>, <C-n>
- Close floating window with <shift>ZZ or any other similar command like :wq

# Example Config

LazyVim
```
return {
  'alf171/quill.nvim',
  config = function()
    require('quill').setup {
      notes_path = '~/Desktop/notes/',
      keymaps = {
        open = '<leader>td',
        close = 'q',
        prev = '<C-p>',
        next = '<C-n>',
      },
    }
  end,
}
```
