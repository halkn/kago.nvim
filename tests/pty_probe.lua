-- Reports whether this environment lets Neovim spawn a pty. Run as a throwaway child process:
-- nvim 0.12.5 segfaults on exit once forkpty has been refused, so the process that reports test
-- results must never attempt the spawn itself.
local ok, result = pcall(vim.fn.jobstart, { vim.o.shell }, { pty = true })
if ok then
  if type(result) == 'number' and result > 0 then
    vim.fn.jobstop(result)
  end
  io.stdout:write('KAGO_PTY_OK\n')
else
  io.stdout:write('KAGO_PTY_REFUSED ' .. tostring(result):gsub('%s+', ' ') .. '\n')
end
io.stdout:flush()
