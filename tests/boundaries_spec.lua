---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local original_input = vim.ui.input
local original_notify = vim.notify
local original_select = vim.ui.select

local input = require('kago.input')
local notify = require('kago.notify')
local picker = require('kago.picker')
local explorer = require('kago.explorer')
local replace = require('kago.replace')
local surround = require('kago.surround')
local terminal = require('kago.terminal')
local yankring = require('kago.yankring')
local pairs_module = require('kago.pairs')

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

local function scratch(lines)
  vim.cmd('enew!')
  vim.bo.buftype = 'nofile'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

describe('integration boundaries', function()
  it('leaves providers and entrypoint mappings to the caller', function()
    assert(rawequal(vim.ui.input, original_input))
    assert(rawequal(vim.ui.select, original_select))
    assert(rawequal(vim.notify, original_notify))

    eq('function', type(input.input))
    eq('function', type(notify.notify))
    notify.setup()
    pairs_module.setup()
    picker.setup()
    explorer.setup()
    replace.setup()
    surround.setup()
    terminal.setup()
    yankring.setup()

    assert(rawequal(vim.ui.input, original_input))
    assert(rawequal(vim.ui.select, original_select))
    assert(rawequal(vim.notify, original_notify))
    for _, lhs in ipairs({ 'sa', 'sd', 'sr', 'R', 'p', 'P', 'gp', 'gP', '<C-p>', '<C-n>' }) do
      assert(vim.fn.maparg(lhs, 'n') == '', 'unexpected normal mapping: ' .. lhs)
    end
    eq('', vim.fn.maparg('<Leader>f', 'n'))
    eq('', vim.fn.maparg('<Leader>e', 'n'))
    eq('', vim.fn.maparg('<C-t>', 'n'))
  end)

  it('surround accepts caller-defined mappings', function()
    surround.setup({ mappings = { add = 'za' } })
    scratch({ 'word' })
    feed('zaiw"')
    eq('"word"', vim.api.nvim_get_current_line())
  end)

  it('replace accepts caller-defined mappings', function()
    replace.setup({ mappings = { replace = 'Q' } })
    scratch({ 'word' })
    vim.fn.setreg('"', 'replacement')
    feed('Qiw')
    eq('replacement', vim.api.nvim_get_current_line())
  end)

  it('pairs accepts caller-defined mappings', function()
    pairs_module.setup({ mappings = { quotes = { '~' } } })
    scratch({ '' })
    feed('i~<Esc>')
    eq('~~', vim.api.nvim_get_current_line())
  end)

  it('yankring accepts caller-defined mappings', function()
    yankring.setup({ mappings = { paste_after = 'zP' } })
    scratch({ 'source', 'target' })
    vim.cmd('normal! y$')
    vim.api.nvim_win_set_cursor(0, { 2, 5 })
    feed('zP')
    eq('targetsource', vim.api.nvim_get_current_line())
  end)
end)
