# kago.nvim

Independent Neovim utility modules for browsing, editing and UI. Install the plugin once, then
enable only the modules and integrations you want.

## Quick start

Neovim 0.12 or newer is required. With `vim.pack`, add the plugin before requiring a module:

```lua
vim.pack.add({ { src = 'https://github.com/halkn/kago.nvim' } })

local explorer = require('kago.explorer')
explorer.setup()
vim.keymap.set('n', '<Leader>e', explorer.toggle)
```

This example opens and closes Explorer with `<Leader>e`. Installing the plugin alone does not
register mappings, commands or provider replacements.

## Dependencies

Other executables are needed only for the features that use them:

| Dependency | Feature |
| --- | --- |
| `git` | Explorer git status and `picker.git()` |
| `rg` (ripgrep) | `picker.files()` and `picker.grep()` |
| `fd` | Explorer path filter (`/`) |

Icon providers are optional. Explorer uses [`nvim-web-devicons`](https://github.com/nvim-tree/nvim-web-devicons)
for file icons when available and generic glyphs otherwise. Picker prefers
[`mini.icons`](https://github.com/nvim-mini/mini.icons), falls back to `nvim-web-devicons`, and
omits icons when neither is available.

## Integration model

There is no top-level `require('kago').setup()`. Each module can be required and configured without
loading or setting up unrelated `kago.*` modules.

Modules do not replace `vim.ui.input`, `vim.ui.select` or `vim.notify`, and they do not create user
commands. Loading a module or calling `setup()` without `mappings` does not add global mappings.
Editing modules install only mappings supplied through `setup({ mappings = ... })`. Modules own the
buffer-local mappings and autocmds needed for their own UI.

## Modules

| Module | Purpose |
| --- | --- |
| [`kago.explorer`](#explorer) | Persistent filesystem sidebar with filtering, git status and preview |
| [`kago.picker`](#picker) | Floating fuzzy picker over files, buffers, grep, buffer lines, tree and git |
| [`kago.input`](#input) | `vim.ui.input` compatible floating prompt |
| [`kago.notify`](#notify) | `vim.notify` compatible floating notifications with history |
| [`kago.terminal`](#terminal) | Floating terminal toggle |
| [`kago.yankring`](#yankring) | Yank ring with paste cycling |
| [`kago.surround`](#surround) | Add / delete / replace surrounding brackets and quotes |
| [`kago.pairs`](#pairs) | Auto-pairing for brackets and quotes |
| [`kago.replace`](#replace) | Operator that replaces a motion range with a register |

### Explorer

The [quick start](#quick-start) configures Explorer and its entrypoint mapping. Call
`explorer.open()` to open it at the current working directory, or pass a root explicitly:

```lua
require('kago.explorer').open({ root = vim.fn.getcwd() })
```

`explorer.close()` and `explorer.toggle()` control the sidebar. Navigation, filtering and preview
keys work only inside its buffer.

### Picker

```lua
local picker = require('kago.picker')

picker.setup({
  debounce_ms = 150,
  height_ratio = 0.8,
  width_ratio = 0.9,
  exclude_globs = { '!**/.git/*' },
})
vim.keymap.set('n', '<Leader>f', picker.files)
```

Open other built-in sources with `picker.buffers()`, `picker.grep()`, `picker.buf_lines()` or
`picker.git()`. `picker.open('files')` accepts a source name, and `picker.close()` closes the
current picker. To use Picker for `vim.ui.select`, assign its standalone adapter explicitly:

```lua
vim.ui.select = picker.ui_select
```

### Input

No setup. `input` is a standalone `vim.ui.input` compatible function:

```lua
vim.ui.input = require('kago.input').input
```

### Notify

```lua
local notify = require('kago.notify')

notify.setup()
vim.notify = notify.notify

vim.api.nvim_create_user_command('NotifyHistory', notify.show_history, {
  desc = 'Show notification history',
})
```

### Terminal

```lua
local terminal = require('kago.terminal')

terminal.setup()
vim.keymap.set({ 'n', 't' }, '<C-t>', terminal.toggle)
```

### Yankring

```lua
require('kago.yankring').setup({
  highlight_ms = 200,
  max_size = 30,
  mappings = {
    paste_after = 'p',
    paste_before = 'P',
    paste_after_end = 'gp',
    paste_before_end = 'gP',
    cycle_prev = '<C-p>',
    cycle_next = '<C-n>',
    show = '<Leader>y',
  },
})
```

### Surround

```lua
require('kago.surround').setup({
  mappings = { add = 'sa', delete = 'sd', replace = 'sr' },
})
```

### Pairs

```lua
require('kago.pairs').setup({
  mappings = {
    pairs = { ['('] = ')', ['['] = ']', ['{'] = '}' },
    quotes = { '"', "'", '`' },
    backspace = { '<BS>', '<C-h>' },
    cr = '<CR>',
  },
})
```

### Replace

```lua
require('kago.replace').setup({ mappings = { replace = 'R' } })
```

## Contributing

Run `make check` before submitting changes. See [Contributing](CONTRIBUTING.md) for local setup,
test conventions and CI behavior.

## License

MIT
