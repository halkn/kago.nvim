---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local picker = require('kago.picker')
local ui = require('kago.picker.ui')
local preview = require('kago.picker.preview')

picker.setup()

---@type string[]
local temporary_paths = {}

local function tempname()
  local path = vim.fn.tempname()
  temporary_paths[#temporary_paths + 1] = path
  return path
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

local function float_win(buf)
  return vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = 40,
    height = 10,
  })
end

---@return integer
local function float_count()
  local count = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).zindex ~= nil then
      count = count + 1
    end
  end
  return count
end

local function nested_select_keeps_its_session()
  local inner, reopened = 'unset', false
  picker.ui_select({ 'a', 'b' }, {}, function()
    picker.ui_select({ 'c', 'd' }, {}, function(value)
      inner = value
    end)
    reopened = true
  end)
  vim.wait(100)
  picker.open('files')
  assert(
    vim.wait(1000, function()
      return reopened
    end),
    'the cancel callback never ran'
  )
  vim.wait(50)
  picker.close()
  assert(
    vim.wait(1000, function()
      return inner ~= 'unset'
    end),
    'the picker opened from a cancel callback lost its callback'
  )
  eq(nil, inner)
  vim.wait(100)
  assert(float_count() == 0, 'closing must not leave picker windows behind')
end

local function sources_open_paths()
  local dir = tempname()
  vim.fn.mkdir(dir, 'p')
  dir = assert(vim.uv.fs_realpath(dir))
  local path = dir .. '/pct%.txt'
  vim.fn.writefile({ 'contents' }, path)

  for name, item in pairs({
    files = { text = path },
    tree = { text = path, _tree_node = { is_dir = false } },
    select = { text = path },
    grep = { text = path .. ':1:contents' },
  }) do
    vim.cmd('enew!')
    require('kago.picker.sources.' .. name).on_accept(item)
    assert(vim.api.nvim_buf_get_name(0) == path, name .. ' opened ' .. vim.api.nvim_buf_get_name(0))
  end
  vim.cmd('enew!')
  vim.fn.delete(dir, 'rf')
end

local function preview_beyond_read_limit()
  local path = tempname()
  local lines = {}
  for i = 1, 500 do
    lines[i] = 'line ' .. i
  end
  vim.fn.writefile(lines, path)

  local buf = vim.api.nvim_create_buf(false, true)
  local state = { preview_buf = buf, preview_win = float_win(buf) }
  preview.show_file(state, path, 450)
  local row = vim.api.nvim_win_get_cursor(state.preview_win)[1]
  assert(
    vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] == 'line 450',
    'preview must point at the requested line'
  )
  assert(
    vim.api.nvim_buf_line_count(buf) <= 200,
    'preview must stay bounded instead of loading everything up to the match'
  )
  preview.show_file(state, path, 1)
  eq('line 1', vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
  eq(1, vim.api.nvim_win_get_cursor(state.preview_win)[1])

  -- A file shorter than the window, written without a trailing newline.
  local short = tempname()
  vim.fn.writefile({ 'a', 'b', 'c' }, short, 'b')
  preview.show_file(state, short, 3)
  row = vim.api.nvim_win_get_cursor(state.preview_win)[1]
  assert(vim.api.nvim_buf_line_count(buf) == 3, 'short files must keep every line')
  eq('c', vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1])
  vim.fn.delete(short)
  vim.api.nvim_win_close(state.preview_win, true)
  vim.fn.delete(path)
end

local function git_source_is_async()
  local git = require('kago.picker.sources.git')
  local system = vim.system
  local pending = {}
  local killed = 0
  vim.system = function(cmd, _, callback)
    pending[#pending + 1] = { cmd = cmd, callback = callback }
    return {
      wait = function()
        error('git source must not block the UI thread')
      end,
      kill = function()
        killed = killed + 1
      end,
    }
  end

  local ok, err = pcall(function()
    local delivered = false
    local handle = git.load({}, { scope = 'branch' }, function()
      delivered = true
    end)
    assert(handle, 'branch scope must return a cancellable handle')
    assert(#pending == 1 and vim.list_contains(pending[1].cmd, 'symbolic-ref'))
    pending[1].callback({ code = 1, stdout = '', stderr = '' })
    assert(#pending == 2 and vim.list_contains(pending[2].cmd, 'rev-parse'))
    pending[2].callback({ code = 0, stdout = 'main\n' })
    assert(#pending == 3 and vim.list_contains(pending[3].cmd, 'diff'))

    handle:kill(9)
    assert(killed == 1, 'cancel must kill the running git process')
    pending[3].callback({ code = 0, stdout = '' })
    vim.wait(50)
    assert(#pending == 3, 'cancelled chain must not spawn the untracked-files job')
    assert(not delivered, 'cancelled chain delivered items')

    pending = {}
    handle = assert(git.load({}, { scope = 'branch' }, function()
      delivered = true
    end))
    pending[1].callback({ code = 0, stdout = 'origin/main\n' })
    pending[2].callback({ code = 0, stdout = '' })
    assert(#pending == 3 and vim.list_contains(pending[3].cmd, 'ls-files'))
    pending[3].callback({ code = 0, stdout = '' })
    assert(vim.wait(1000, function()
      return delivered
    end))
    handle:kill(9)
  end)

  vim.system = system
  assert(ok, err)
end

describe('picker', function()
  after_each(function()
    picker.close()
    vim.cmd('stopinsert')
    vim.cmd('silent! only!')
    vim.cmd('silent! %bwipeout!')
    for _, path in ipairs(temporary_paths) do
      vim.fn.delete(path, 'rf')
    end
    temporary_paths = {}
  end)

  for _, source in ipairs({ 'files', 'buffers', 'grep', 'buf_lines', 'tree', 'git' }) do
    it('opens and closes the ' .. source .. ' source', function()
      picker.open(source)
      vim.wait(100)
      assert(float_count() > 0, 'source must open picker windows')
      picker.close()
      assert(float_count() == 0, 'close must remove picker windows')
    end)
  end

  it('cancels select exactly once', function()
    local cancelled = {}
    picker.ui_select({ 'a', 'b' }, { prompt = 'module test' }, function(value)
      cancelled[#cancelled + 1] = { value = value }
    end)
    vim.wait(100)
    assert(vim.api.nvim_get_current_buf() ~= 0)
    picker.close()
    assert(
      vim.wait(1000, function()
        return #cancelled > 0
      end),
      'cancel must call on_choice'
    )
    vim.wait(100)
    assert(#cancelled == 1, 'cancel must call on_choice exactly once')
    eq(nil, cancelled[1].value)
  end)

  it('select returns the original item and index after filtering', function()
    local items = { { id = 'first' }, { id = 'second' } }
    ---@type table
    local accepted = { calls = 0 }
    picker.ui_select(items, {
      prompt = 'pick',
      format_item = function(item)
        return 'item ' .. item.id
      end,
    }, function(value, idx)
      accepted.calls = accepted.calls + 1
      accepted.value, accepted.idx = value, idx
    end)
    vim.wait(100)
    local prompt = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(prompt, 0, -1, false, { '> second' })
    vim.api.nvim_exec_autocmds('TextChangedI', { buffer = prompt })
    vim.wait(50)
    feed('i<CR>')
    vim.wait(100)
    assert(accepted.calls == 1, 'accept must call on_choice exactly once')
    assert(rawequal(accepted.value, items[2]), 'on_choice must receive the original item')
    assert(accepted.idx == 2, 'on_choice must receive the item index')
  end)

  it('filter preserves identity and clears stale highlights', function()
    local alpha, beta = { text = 'alpha' }, { text = 'beta' }
    local filtered = ui.default_filter({ alpha, beta }, 'alp')
    assert(#filtered == 1 and rawequal(filtered[1], alpha), 'filter must preserve item identity')
    assert(alpha._match_pos, 'matched item needs highlight positions')
    ui.default_filter({ alpha, beta }, '')
    assert(alpha._match_pos == nil, 'an empty query must clear stale highlight positions')
  end)

  it('preserves a select session opened by a cancel callback', nested_select_keeps_its_session)
  it('opens paths containing percent signs', sources_open_paths)
  it('previews requested lines beyond the read limit', preview_beyond_read_limit)
  it('loads Git asynchronously and cancels stale results', git_source_is_async)
end)
