-- Reports whether this environment lets Neovim spawn a pty. Run as a throwaway child process:
-- nvim 0.12.5 segfaults on exit once forkpty has been refused, so the process that reports test
-- results must never attempt the spawn itself.
local ok, result = pcall(vim.fn.jobstart, { vim.o.shell }, { pty = true })
if not ok then
  io.stdout:write('KAGO_PTY_REFUSED ' .. tostring(result):gsub('%s+', ' ') .. '\n')
elseif type(result) == 'number' and result > 0 then
  vim.fn.jobstop(result)
  io.stdout:write('KAGO_PTY_OK\n')
else
  -- jobstart returns 0 or -1 without raising, so a successful call is not yet a running pty.
  io.stdout:write('KAGO_PTY_UNKNOWN ' .. tostring(result) .. '\n')
end
io.stdout:flush()
