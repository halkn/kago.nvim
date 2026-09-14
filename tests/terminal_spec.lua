---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local terminal = require('kago.terminal')

describe('floating terminal', function()
  after_each(function()
    vim.cmd('stopinsert')
    vim.cmd('silent! only!')
    vim.cmd('silent! %bwipeout!')
  end)

  it('replaces an exited terminal and releases its old buffer', function()
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

  it('keeps a running shell when hidden and reopened', function()
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
