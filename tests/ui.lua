-- vim.ui.input replacement, notification floats and the terminal toggle.
local input = require('kago.input')
local notify = require('kago.notify')
local terminal = require('kago.terminal')

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

-- Only floats report a zindex.
local function is_float(win)
  return vim.api.nvim_win_get_config(win).zindex ~= nil
end

---@return integer
local function float_count()
  local count = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if is_float(win) then
      count = count + 1
    end
  end
  return count
end

local function input_reports_empty_confirm()
  local calls, got = 0, 'unset'
  input.input({ prompt = 'Name', default = 'old' }, function(value)
    calls = calls + 1
    got = value
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
  feed('i<CR>')
  assert(calls == 1, 'confirm must call on_confirm once')
  assert(got == '', 'a confirmed empty line is not a cancel')
end

local function input_cancels_when_window_is_left()
  local home = vim.api.nvim_get_current_win()
  local calls, got = 0, 'unset'
  input.input({ prompt = 'Name' }, function(value)
    calls = calls + 1
    got = value
  end)
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.cmd('stopinsert')
  vim.api.nvim_set_current_win(home)
  assert(
    vim.wait(1000, function()
      return calls > 0
    end),
    'leaving the input window must cancel'
  )
  assert(got == nil and calls == 1)
  assert(not vim.api.nvim_win_is_valid(win), 'cancelled input left its window open')
  assert(not vim.api.nvim_buf_is_valid(buf))
end

local function notify_keeps_caller_opts()
  notify.setup()
  local opts = { title = 'build', timeout = false }
  local before = float_count()
  local first = notify.notify('one', vim.log.levels.INFO, opts)
  local second = notify.notify('two', vim.log.levels.INFO, opts)
  assert(opts.id == nil, 'notify must not write an id into the caller table')
  assert(first ~= second, 'independent notifications need distinct ids')
  vim.wait(200)
  assert(
    float_count() == before + 2,
    'a reused opts table collapsed unrelated notifications into one float'
  )
end

local function terminal_replaces_dead_buffer()
  terminal.setup()
  if not pcall(terminal.toggle) then
    -- Sandboxed runners cannot spawn a pty, so no terminal buffer exists to replace.
    io.write('terminal replacement skipped: no pty available\n')
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  assert(is_float(0), 'toggle must open a float')
  assert(vim.bo[buf].buftype == 'terminal')
  local job = math.floor(vim.b[buf].terminal_job_id)
  vim.fn.jobstop(job)
  assert(
    vim.wait(5000, function()
      return vim.fn.jobwait({ job }, 0)[1] ~= -1
    end),
    'terminal job did not exit'
  )
  terminal.toggle()
  terminal.toggle()
  assert(vim.api.nvim_get_current_buf() ~= buf, 'dead terminal should be replaced')
  assert(not vim.api.nvim_buf_is_valid(buf), 'dead terminal buffer was leaked')
  terminal.toggle()
end

local function run()
  vim.cmd('new')
  input_reports_empty_confirm()
  input_cancels_when_window_is_left()
  notify_keeps_caller_opts()
  terminal_replaces_dead_buffer()
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
end
io.write('ui modules test passed\n')
vim.cmd('qa!')
