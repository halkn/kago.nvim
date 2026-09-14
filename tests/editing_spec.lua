---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local pairs_module = require('kago.pairs')
local replace = require('kago.replace')
local surround = require('kago.surround')
local yankring = require('kago.yankring')

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

local function scratch(lines)
  vim.cmd('enew!')
  vim.bo.buftype = 'nofile'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

describe('editing mappings', function()
  before_each(function()
    package.loaded['kago.yankring'] = nil
    yankring = require('kago.yankring')
    vim.g.mapleader = ' '

    pairs_module.setup({
      mappings = {
        pairs = { ['('] = ')', ['['] = ']', ['{'] = '}' },
        quotes = { '"', "'", '`' },
        backspace = { '<BS>', '<C-h>' },
        cr = '<CR>',
      },
    })
    replace.setup({ mappings = { replace = 'R' } })
    surround.setup({ mappings = { add = 'sa', delete = 'sd', replace = 'sr' } })
    yankring.setup({
      mappings = {
        paste_after = 'p',
        paste_before = 'P',
        paste_after_end = 'gp',
        paste_before_end = 'gP',
        cycle_prev = '<C-p>',
        cycle_next = '<C-n>',
      },
    })
  end)

  after_each(function()
    vim.cmd('stopinsert')
    vim.cmd('silent! %bwipeout!')
  end)

  it('surround adds quotes around a motion', function()
    scratch({ 'word' })
    feed('saiw"')
    eq('"word"', vim.api.nvim_get_current_line())
  end)

  it('surround adds brackets around a visual selection', function()
    scratch({ 'alpha beta' })
    vim.cmd('normal! 0v$')
    feed('sa[')
    eq('[ alpha beta ]', vim.api.nvim_get_current_line())
  end)

  it('surround repeats with dot', function()
    scratch({ 'one two' })
    feed('saiw"')
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    feed('.')
    assert(vim.api.nvim_get_current_line() == '"one" "two"', vim.api.nvim_get_current_line())
  end)

  it('surround deletes quotes', function()
    scratch({ '"alpha"' })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    feed('sd"')
    assert(vim.api.nvim_get_current_line() == 'alpha', vim.api.nvim_get_current_line())
  end)

  it('surround replaces delimiters', function()
    scratch({ '"alpha"' })
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    feed('sr"[')
    eq('[ alpha ]', vim.api.nvim_get_current_line())
  end)

  it('replace uses a motion', function()
    scratch({ 'alpha beta' })
    vim.cmd('normal! yiw')
    feed('wRiw')
    eq('alpha alpha', vim.api.nvim_get_current_line())
  end)

  it('replace uses a visual selection', function()
    scratch({ 'alpha beta' })
    vim.cmd('normal! 0v$')
    vim.fn.setreg('"', 'replacement')
    feed('R')
    eq('replacement', vim.api.nvim_get_current_line())
  end)

  it('yankring cycles multibyte text', function()
    scratch({ 'xyz', 'あい', 'target' })
    vim.cmd('normal! y$')
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd('normal! y$')
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.cmd('normal! $')
    feed('p')
    eq('targetあい', vim.api.nvim_get_current_line())
    feed('<C-n>')
    eq('targetxyz', vim.api.nvim_get_current_line())
  end)

  it('yankring cycles whole lines without changing line count', function()
    scratch({ 'aaa', 'bbb', 'XXX' })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.cmd('normal! yy')
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd('normal! yy')
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    feed('p<C-n>')
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert(#lines == 4, 'cycle changed the line count: ' .. vim.inspect(lines))
    assert(lines[2] == 'XXX', 'cycle: ' .. vim.inspect(lines))
  end)

  it('yankring honors named registers', function()
    scratch({ 'REG', 'RING', 'target' })
    vim.cmd('normal! "ay$')
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd('normal! y$')
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.cmd('normal! $')
    feed('"ap')
    eq('targetREG', vim.api.nvim_get_current_line())
  end)

  it('yankring honors paste counts', function()
    scratch({ 'RING', 'target' })
    vim.cmd('normal! y$')
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd('normal! $')
    feed('3p')
    eq('targetRINGRINGRING', vim.api.nvim_get_current_line())
  end)

  it('pairs respects odd and even escaping', function()
    scratch({ 'a\\' })
    feed('A(<Esc>')
    eq('a\\(', vim.api.nvim_get_current_line())
    scratch({ 'a\\\\' })
    feed('A(<Esc>')
    eq('a\\\\()', vim.api.nvim_get_current_line())
  end)

  for _, pair in ipairs({ { '(', ')' }, { '[', ']' }, { '{', '}' }, { '"', '"' } }) do
    it('pairs inserts and skips the closing ' .. pair[2], function()
      scratch({ '' })
      feed('i' .. pair[1] .. 'text' .. pair[2] .. '!<Esc>')
      eq(pair[1] .. 'text' .. pair[2] .. '!', vim.api.nvim_get_current_line())
    end)
  end

  for _, key in ipairs({ '<BS>', '<C-h>' }) do
    it('pairs deletes both delimiters with ' .. key, function()
      scratch({ '' })
      feed('i(' .. key .. '<Esc>')
      eq('', vim.api.nvim_get_current_line())
    end)
  end

  it('pairs inserts a single apostrophe inside a word', function()
    scratch({ 'don' })
    feed("A't<Esc>")
    eq("don't", vim.api.nvim_get_current_line())
  end)

  it('pairs creates an empty line between brackets on Enter', function()
    scratch({ '' })
    feed('i{<CR><Esc>')
    eq({ '{', '', '}' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    eq(2, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it('pairs closes an opening markdown fence on Enter', function()
    scratch({ '```lua' })
    feed('A<CR><Esc>')
    eq({ '```lua', '', '```' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('pairs does not add another fence after a closing fence', function()
    scratch({ '```lua', 'code', '```' })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    feed('A<CR><Esc>')
    eq({ '```lua', 'code', '```', '' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)
