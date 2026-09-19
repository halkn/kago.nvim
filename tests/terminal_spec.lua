-- Floating terminal behaviour, verified against a real pty.
---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local terminal = require('kago.terminal')

-- Asking the probe instead of kago.terminal keeps a refused spawn (E903) the only reason to go
-- pending, so every toggle error stays a failure. nvim 0.12.5 segfaults on exit once forkpty has
-- been refused, hence the child process and the marker rather than its exit code.
---@return boolean
local function pty_available()
  local out = vim.fn.system({
    vim.v.progpath,
    '--headless',
    '-n',
    '-i',
    'NONE',
    '-u',
    'tests/minimal_init.lua',
    '-l',
    'tests/pty_probe.lua',
  })
  if out:find('KAGO_PTY_OK', 1, true) then
    return true
  end
  local refused = out:match('KAGO_PTY_REFUSED[^\n]*')
  if not refused or not refused:find('E903', 1, true) then
    error('pty probe did not report a refused spawn: ' .. out, 0)
  end
  print('terminal specs pending, ' .. refused)
  return false
end

describe('floating terminal', function()
  local case = pty_available() and it or pending

  after_each(function()
    vim.cmd('stopinsert')
    vim.cmd('silent! only!')
    vim.cmd('silent! %bwipeout!')
  end)

  case('replaces an exited terminal and releases its old buffer', function()
    terminal.setup()
    terminal.toggle()
    local buf = vim.api.nvim_get_current_buf()
    assert(vim.api.nvim_win_get_config(0).zindex ~= nil, 'toggle must open a float')
    eq('terminal', vim.bo[buf].buftype)

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
  end)

  case('keeps a running shell when hidden and reopened', function()
    terminal.setup()
    terminal.toggle()
    local buf = vim.api.nvim_get_current_buf()
    local job = math.floor(vim.b[buf].terminal_job_id)
    terminal.toggle()
    assert(vim.api.nvim_buf_is_valid(buf))
    eq(-1, vim.fn.jobwait({ job }, 0)[1])
    terminal.toggle()
    eq(buf, vim.api.nvim_get_current_buf())
    eq(job, vim.b[buf].terminal_job_id)
    terminal.toggle()
  end)
end)
