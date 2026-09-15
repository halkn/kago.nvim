vim.opt.runtimepath = {
  vim.fn.getcwd(),
  vim.env.VIMRUNTIME,
  vim.fn.fnamemodify(vim.fn.resolve(vim.v.progpath), ':h:h') .. '/lib/nvim',
  vim.fn.getcwd() .. '/.deps/plenary.nvim',
}
vim.opt.shadafile = 'NONE'
vim.opt.swapfile = false
vim.opt.shell = '/bin/sh'
vim.opt.packpath = ''
vim.opt.loadplugins = false
vim.env.NVIM_LOG_FILE = '/dev/null'

-- Luassert returns extra values from assert(value), breaking calls such as
-- nvim_win_get_cursor(assert(win)). Keep Lua's assert for the modules under test.
local lua_assert = assert
require('plenary.busted')
_G.assert = lua_assert
