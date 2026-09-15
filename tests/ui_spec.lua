-- vim.ui.input replacement and notification floats.
local input = require('kago.input')
local notify = require('kago.notify')

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

local function notify_owns_title_highlights()
  local cases = {
    {
      level = vim.log.levels.ERROR,
      diagnostic_hl = 'DiagnosticError',
      title_hl = 'KagoNotifyTitleError',
      old_title_hl = 'NotifyTitleError',
    },
    {
      level = vim.log.levels.WARN,
      diagnostic_hl = 'DiagnosticWarn',
      title_hl = 'KagoNotifyTitleWarn',
      old_title_hl = 'NotifyTitleWarn',
    },
    {
      level = vim.log.levels.INFO,
      diagnostic_hl = 'DiagnosticInfo',
      title_hl = 'KagoNotifyTitleInfo',
      old_title_hl = 'NotifyTitleInfo',
    },
    {
      level = vim.log.levels.DEBUG,
      diagnostic_hl = 'DiagnosticHint',
      title_hl = 'KagoNotifyTitleDebug',
      old_title_hl = 'NotifyTitleDebug',
    },
    {
      level = vim.log.levels.TRACE,
      diagnostic_hl = 'DiagnosticHint',
      title_hl = 'KagoNotifyTitleTrace',
      old_title_hl = 'NotifyTitleTrace',
    },
  }

  notify.setup()
  local ids = {}
  for _, case in ipairs(cases) do
    local title_hl = vim.api.nvim_get_hl(0, { name = case.title_hl })
    local diagnostic_hl = vim.api.nvim_get_hl(0, { name = case.diagnostic_hl })
    assert(title_hl.fg == diagnostic_hl.fg, case.title_hl .. ' must use the diagnostic color')
    assert(title_hl.bold == true, case.title_hl .. ' must remain bold')
    assert(
      vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = case.old_title_hl })),
      case.old_title_hl .. ' must not be defined'
    )

    ids[case.level] = notify.notify('message', case.level, {
      title = case.title_hl,
      timeout = false,
    })
  end

  assert(
    vim.wait(1000, function()
      local found = 0
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local cfg = vim.api.nvim_win_get_config(win)
        if type(cfg.title) == 'table' then
          found = found + 1
        end
      end
      return found == #cases
    end),
    'notifications did not open'
  )

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if type(cfg.title) == 'table' then
      local title = cfg.title[1]
      local title_hl = title and title[2]
      local level = title and title[1]:match('KagoNotifyTitle(%a+)')
      local log_level = level and vim.log.levels[level:upper()]
      if log_level and ids[log_level] then
        assert(title_hl == 'KagoNotifyTitle' .. level)
        ids[log_level] = nil
      end
    end
  end
  assert(vim.tbl_isempty(ids), 'every notification level must use its Kago title highlight')

  for _, case in ipairs(cases) do
    vim.api.nvim_set_hl(0, case.title_hl, {})
  end
  vim.api.nvim_exec_autocmds('ColorScheme', {})
  for _, case in ipairs(cases) do
    local title_hl = vim.api.nvim_get_hl(0, { name = case.title_hl })
    local diagnostic_hl = vim.api.nvim_get_hl(0, { name = case.diagnostic_hl })
    assert(title_hl.fg == diagnostic_hl.fg, case.title_hl .. ' must be restored after ColorScheme')
    assert(title_hl.bold == true, case.title_hl .. ' must remain bold after ColorScheme')
  end
end

describe('input and notifications', function()
  before_each(function()
    vim.cmd('new')
  end)

  after_each(function()
    vim.cmd('stopinsert')
    vim.cmd('silent! only!')
    vim.cmd('silent! %bwipeout!')
  end)

  it('confirms an empty input exactly once', input_reports_empty_confirm)
  it('cancels input and cleans up when leaving the window', input_cancels_when_window_is_left)
  it(
    'does not mutate notification options or merge unrelated notifications',
    notify_keeps_caller_opts
  )
  it('owns and restores notification title highlights', notify_owns_title_highlights)
end)
