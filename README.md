# kago.nvim

Neovim utility modules, packaged as one repository of independent sub-plugins.

Each module is a self-contained feature — an explorer, a picker, a notifier, editing operators —
that can be adopted one at a time. Installing the plugin changes nothing on its own: every mapping,
provider replacement and user command stays on the calling side.

## Design principles

- **Independent modules.** A module never requires another `kago.*` module to be set up.
- **No top-level setup.** There is no `require("kago").setup()`; configure each module directly.
- **No implicit global integration.** Loading or setting up a module does not register personal
  entrypoint mappings, replace `vim.ui.input` / `vim.ui.select` / `vim.notify`, or create user
  commands. Buffer-local mappings and autocmds a module needs for its own UI are owned by that
  module.
- **No speculative shared framework.** Similar code across modules is left duplicated until a real
  change reason justifies a private abstraction.

## Requirements

- Neovim 0.12 or newer
- `git` — Explorer git status, `picker.git()`
- `rg` (ripgrep) — `picker.files()`, `picker.grep()`
- `fd` — Explorer path filter (`/`)

## Optional dependencies

- [`nvim-web-devicons`](https://github.com/nvim-tree/nvim-web-devicons) — file icons in Explorer and
  Picker. Without it both fall back to text-only rendering.

## Installation

With `vim.pack`:

```lua
vim.pack.add({ { src = 'https://github.com/halkn/kago.nvim' } })
```

`require("kago.*")` only works after the plugin is on `runtimepath`, so module setup has to run
after `vim.pack.add()`.

## Modules

| Module | Purpose |
| --- | --- |
| `kago.explorer` | Persistent filesystem sidebar with filtering, git status and preview |
| `kago.picker` | Floating fuzzy picker over files, buffers, grep, buffer lines, tree and git |
| `kago.input` | `vim.ui.input` compatible floating prompt |
| `kago.notify` | `vim.notify` compatible floating notifications with history |
| `kago.terminal` | Floating terminal toggle |
| `kago.yankring` | Yank ring with paste cycling |
| `kago.surround` | Add / delete / replace surrounding brackets and quotes |
| `kago.pairs` | Auto-pairing for brackets and quotes |
| `kago.replace` | Operator that replaces a motion range with a register |

### Explorer

```lua
local explorer = require('kago.explorer')

explorer.setup()

explorer.open(opts)
explorer.close()
explorer.toggle()

vim.keymap.set('n', '<Leader>e', explorer.toggle)
```

Navigation, filtering and preview mappings inside the explorer window are buffer-local and owned by
the module.

### Picker

```lua
local picker = require('kago.picker')

picker.setup({
  debounce_ms = 150,
  height_ratio = 0.8,
  width_ratio = 0.9,
  exclude_globs = { '!**/.git/*' },
})

picker.open(source_name, opts)
picker.close()

picker.files()
picker.buffers()
picker.grep()
picker.buf_lines()
picker.git()
```

`ui_select` is a standalone `vim.ui.select` compatible function. Adopting it is the caller's choice:

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

notify.setup({
  display_ms = 3000,
  max_history = 50,
  max_width_ratio = 0.4,
  min_width = 30,
})

vim.notify = notify.notify

vim.api.nvim_create_user_command('NotifyHistory', notify.show_history, {
  desc = 'Show notification history',
})
```

### Terminal

```lua
local terminal = require('kago.terminal')

terminal.setup({ height_ratio = 0.85, width_ratio = 0.85 })

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

## Mapping ownership

Editing modules register no mappings unless `mappings` is passed to `setup()`, and no module
registers a global entrypoint mapping. `tests/boundaries_spec.lua` holds that contract, and
`tests/independence_spec.lua` holds the one that requiring a module never loads an unrelated one.

## Development

Tooling is declared in `mise.toml`. Tests use
[Plenary's Busted-style runner and luassert](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md)
inside real headless Neovim processes. Plenary is a **test-only dependency**, downloaded into
`.deps/plenary.nvim` on the first test run and pinned to the commit in `tests/deps.sh`.

```sh
mise run fmt        # stylua
mise run fmt-check  # stylua --check
mise run lint       # emmylua_check
mise run test       # discover and run tests/**/*_spec.lua
mise run test tests/editing_spec.lua  # run one spec
mise run check      # formatting, static analysis and tests
```

Each spec runs in a separate Neovim with `tests/minimal_init.lua`, without user configuration,
installed plugins, ShaDa or swap files. Use `describe` / `it` for named behaviors and
`before_each` / `after_each` for fixtures and cleanup. Tests exercise mappings, buffers, windows,
callbacks and external processes; assertions fail the command and CI. The terminal spec requires
a PTY and fails if one is unavailable.

For value comparisons, use `local eq = require('luassert').same` and `eq(expected, actual)`.
The initializer preserves Lua's standard `assert` because modules use its return value in Neovim
API calls. `tests/types/` declares the test APIs for static analysis without importing Plenary's
global `assert` type into plugin code.

New specs are discovered automatically; no task or CI file list needs updating. Keep cases
independent, create temporary files in fixtures, and release windows, buffers and process stubs
in cleanup hooks. A lifecycle scenario can remain one case when its steps intentionally share
state.

## License

MIT
