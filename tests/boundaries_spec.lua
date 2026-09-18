---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local original_input = vim.ui.input
local original_notify = vim.notify
local original_select = vim.ui.select

-- nvim_get_keymap reports global mappings per mode. Buffer-local mappings owned by a
-- module's own UI never enter these snapshots.
local mapped_modes = { 'n', 'x', 's', 'o', 'i', 'l', 'c', 't' }

---@param mode string
---@return table<string, boolean>
local function global_lhs(mode)
  local set = {}
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    set[map.lhs] = true
  end
  return set
end

---@return table<string, boolean>
local function user_commands()
  local set = {}
  for name in pairs(vim.api.nvim_get_commands({})) do
    set[name] = true
  end
  return set
end

---@param before table<string, boolean>
---@param after table<string, boolean>
---@return string[]
local function added(before, after)
  local names = {}
  for name in pairs(after) do
    if not before[name] then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

local original_commands = user_commands()
---@type table<string, table<string, boolean>>
local original_maps = {}
for _, mode in ipairs(mapped_modes) do
  original_maps[mode] = global_lhs(mode)
end

-- The caller-defined mapping specs register global mappings on purpose. Reverting them
-- keeps the snapshot comparisons independent of spec order.
local function restore_globals()
  for _, mode in ipairs(mapped_modes) do
    for lhs in pairs(global_lhs(mode)) do
      if original_maps[mode][lhs] == nil then
        pcall(vim.keymap.del, mode, lhs)
      end
    end
  end
  for name in pairs(user_commands()) do
    if original_commands[name] == nil then
      pcall(vim.api.nvim_del_user_command, name)
    end
  end
end

local input = require('kago.input')
local notify = require('kago.notify')
local picker = require('kago.picker')
local explorer = require('kago.explorer')
local replace = require('kago.replace')
local surround = require('kago.surround')
local terminal = require('kago.terminal')
local yankring = require('kago.yankring')
local pairs_module = require('kago.pairs')

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

-- Every module is set up without mapping configuration, matching a caller that opts
-- into module setup while retaining ownership of its global mappings.
local function setup_all()
  notify.setup()
  pairs_module.setup()
  picker.setup()
  explorer.setup()
  replace.setup()
  surround.setup()
  terminal.setup()
  yankring.setup()
end

local function scratch(lines)
  vim.cmd('enew!')
  vim.bo.buftype = 'nofile'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

describe('integration boundaries', function()
  after_each(restore_globals)

  it('leaves providers and entrypoint mappings to the caller', function()
    assert(rawequal(vim.ui.input, original_input))
    assert(rawequal(vim.ui.select, original_select))
    assert(rawequal(vim.notify, original_notify))

    eq('function', type(input.input))
    eq('function', type(notify.notify))
    setup_all()

    assert(rawequal(vim.ui.input, original_input))
    assert(rawequal(vim.ui.select, original_select))
    assert(rawequal(vim.notify, original_notify))
    for _, lhs in ipairs({ 'sa', 'sd', 'sr', 'R', 'p', 'P', 'gp', 'gP', '<C-p>', '<C-n>' }) do
      assert(vim.fn.maparg(lhs, 'n') == '', 'unexpected normal mapping: ' .. lhs)
    end
    eq('', vim.fn.maparg('<Leader>f', 'n'))
    eq('', vim.fn.maparg('<Leader>e', 'n'))
    eq('', vim.fn.maparg('<C-t>', 'n'))
  end)

  it('leaves user commands to the caller', function()
    setup_all()

    local names = added(original_commands, user_commands())
    eq({}, names, 'unexpected user commands: ' .. table.concat(names, ', '))
  end)

  it('leaves global mappings to the caller', function()
    setup_all()

    for _, mode in ipairs(mapped_modes) do
      local lhs = added(original_maps[mode], global_lhs(mode))
      eq({}, lhs, ('unexpected %s mappings: %s'):format(mode, table.concat(lhs, ', ')))
    end
  end)

  it('surround accepts caller-defined mappings', function()
    surround.setup({ mappings = { add = 'za' } })
    scratch({ 'word' })
    feed('zaiw"')
    eq('"word"', vim.api.nvim_get_current_line())
  end)

  -- zq rather than Q: Nvim maps Q in Visual mode by default, and overwriting it here
  -- would leave the snapshots unable to tell a test fixture from a leak.
  it('replace accepts caller-defined mappings', function()
    replace.setup({ mappings = { replace = 'zq' } })
    scratch({ 'word' })
    vim.fn.setreg('"', 'replacement')
    feed('zqiw')
    eq('replacement', vim.api.nvim_get_current_line())
  end)

  it('pairs accepts caller-defined mappings', function()
    pairs_module.setup({ mappings = { quotes = { '~' } } })
    scratch({ '' })
    feed('i~<Esc>')
    eq('~~', vim.api.nvim_get_current_line())
  end)

  it('yankring accepts caller-defined mappings', function()
    yankring.setup({ mappings = { paste_after = 'zP' } })
    scratch({ 'source', 'target' })
    vim.cmd('normal! y$')
    vim.api.nvim_win_set_cursor(0, { 2, 5 })
    feed('zP')
    eq('targetsource', vim.api.nvim_get_current_line())
  end)
end)
