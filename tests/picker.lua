local picker = require('kago.picker')
local ui = require('kago.picker.ui')
local preview = require('kago.picker.preview')

picker.setup()

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

local function sources_open_paths()
  local dir = vim.fn.tempname()
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
  local path = vim.fn.tempname()
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

local function run()
  for _, source in ipairs({ 'files', 'buffers', 'grep', 'buf_lines', 'tree', 'git' }) do
    picker.open(source)
    vim.wait(100)
    picker.close()
  end

  local cancelled = {}
  picker.ui_select({ 'a', 'b' }, { prompt = 'module test' }, function(value)
    cancelled[#cancelled + 1] = { value = value }
  end)
  vim.wait(100)
  assert(vim.api.nvim_get_current_buf() ~= 0)
  picker.close()
  assert(#cancelled == 1, 'cancel must call on_choice exactly once')
  assert(cancelled[1].value == nil)

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

  local alpha, beta = { text = 'alpha' }, { text = 'beta' }
  local filtered = ui.default_filter({ alpha, beta }, 'alp')
  assert(#filtered == 1 and rawequal(filtered[1], alpha), 'filter must preserve item identity')
  assert(alpha._match_pos, 'matched item needs highlight positions')
  ui.default_filter({ alpha, beta }, '')
  assert(alpha._match_pos == nil, 'an empty query must clear stale highlight positions')

  sources_open_paths()
  preview_beyond_read_limit()
  git_source_is_async()
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
end
io.write('picker modules test passed\n')
vim.cmd('qa!')
