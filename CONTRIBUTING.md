# Contributing

The [README integration model](README.md#integration-model) describes the behavior users can rely
on. [Repository guidance](AGENTS.md) contains the design and verification rules for changes.

## Local checks

Put Neovim, StyLua, EmmyLua Check, ripgrep and fd on `PATH`. `make test` downloads the pinned
Plenary test dependency into `.deps/plenary.nvim` on its first run.

```sh
make check                            # formatting, static analysis and all tests
make test TEST=tests/editing_spec.lua # one spec
make fmt                              # apply Lua formatting
```

The Makefile also provides `fmt-check`, `lint` and `test` targets.

## Tests

Tests use [Plenary's Busted-style runner and luassert](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md)
inside headless Neovim. The full suite runs each spec in a separate process with
`tests/minimal_init.lua`, without the user's configuration or installed plugins, ShaDa or swap
files. New `tests/**/*_spec.lua` files are discovered automatically.

Use `describe` and `it` to name behaviors, and `before_each` / `after_each` for fixtures and cleanup.
Keep cases independent, create temporary files in fixtures, and release windows, buffers and
process stubs after use. A lifecycle scenario can stay in one case when its steps share state.

For value comparisons, use `local eq = require('luassert').same` and `eq(expected, actual)`.
`tests/minimal_init.lua` preserves Lua's standard `assert` because plugin code uses its return
value. `tests/types/` declares the test APIs for static analysis without importing Plenary's
global `assert` type into plugin code.

`tests/boundaries_spec.lua` covers global integration ownership, and
`tests/independence_spec.lua` checks that requiring a module does not load unrelated modules.

## CI and terminal tests

CI runs `make check` with stable Neovim and `make test` with the minimum supported version,
Neovim 0.12.0.

The terminal spec requires a PTY. `tests/pty_probe.lua` detects whether the local environment can
spawn one; when it cannot, that spec is reported pending. CI sets `KAGO_TEST_REQUIRE_PTY=1` so a
refused spawn fails the run. Other terminal errors also fail locally.
