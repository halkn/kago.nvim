local eq = require('luassert').same
local picker = require('kago.picker')

local system = vim.system
---@type { cmd: string[], callback: fun(result: vim.SystemCompleted), killed: boolean }[]
local pending = {}

local function buffer_with_filetype(filetype)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == filetype then
      return buf
    end
  end
  error('missing buffer: ' .. filetype)
end

local function query(text)
  local prompt = buffer_with_filetype('picker_prompt')
  vim.api.nvim_buf_set_lines(prompt, 0, -1, false, { '> ' .. text })
  vim.api.nvim_exec_autocmds('TextChangedI', { buffer = prompt })
end

local function lines()
  return vim.api.nvim_buf_get_lines(buffer_with_filetype('picker_list'), 0, -1, false)
end

describe('picker source lifecycle', function()
  before_each(function()
    pending = {}
    vim.system = function(cmd, _, callback)
      local request = { cmd = cmd, callback = assert(callback), killed = false }
      pending[#pending + 1] = request
      return {
        kill = function()
          request.killed = true
        end,
      }
    end
  end)

  after_each(function()
    picker.close()
    vim.cmd.stopinsert()
    vim.wait(20)
    vim.system = system
    vim.cmd('silent! only!')
    vim.cmd('silent! %bwipeout!')
  end)

  for _, transition in ipairs({ 'close and reopen', 'switch sources' }) do
    it('discards old tree results after ' .. transition, function()
      picker.open('tree')
      local old = assert(pending[1])
      if transition == 'close and reopen' then
        picker.close()
        picker.open('tree')
      else
        picker._switch_source('files')
        picker._switch_source('tree')
      end
      assert(old.killed, 'transition must cancel the old loader')
      local current = pending[#pending]
      current.callback({ code = 0, signal = 0, stderr = '', stdout = 'fresh-only-entry.txt\n' })
      vim.wait(20)
      old.callback({ code = 0, signal = 0, stderr = '', stdout = 'stale-only-entry.txt\n' })
      vim.wait(20)
      query('fresh-only-entry')
      assert(table.concat(lines(), '\n'):find('fresh-only-entry.txt', 1, true))
      query('stale-only-entry')
      eq({ '' }, lines())
    end)
  end

  it('discards a tree result already queued before close', function()
    picker.open('tree')
    assert(pending[1]).callback({
      code = 0,
      signal = 0,
      stderr = '',
      stdout = 'stale-only-entry.txt\n',
    })
    picker.close()
    picker.open('tree')
    vim.wait(20)
    query('stale-only-entry')
    assert(not table.concat(lines(), '\n'):find('stale-only-entry.txt', 1, true))
    assert(pending[2]).callback({
      code = 0,
      signal = 0,
      stderr = '',
      stdout = 'fresh-only-entry.txt\n',
    })
    vim.wait(20)
    query('fresh-only-entry')
    assert(table.concat(lines(), '\n'):find('fresh-only-entry.txt', 1, true))
  end)

  it('cancels a debounced grep query when switching sources', function()
    picker.setup()
    picker.open('grep')
    vim.wait(20)
    query('stale-query')
    picker._switch_source('files')
    vim.wait(250)
    eq(1, #pending, 'only the files loader should run')
    assert(vim.list_contains(assert(pending[1]).cmd, '--files'))
  end)
end)
