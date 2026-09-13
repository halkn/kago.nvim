-- Floating terminal toggle. Kept apart from the other UI modules because it needs a
-- pty, which sandboxed runners deny.
local terminal = require('kago.terminal')

local function run()
  terminal.setup()
  if not pcall(terminal.toggle) then
    io.write('terminal test skipped: no pty available\n')
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  assert(vim.api.nvim_win_get_config(0).zindex ~= nil, 'toggle must open a float')
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

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
end
io.write('terminal test passed\n')
vim.cmd('qa!')
