local M = {}
local entries = require('kago.explorer._internal.entries')
local view = require('kago.explorer._internal.view')
local bindings = require('kago.explorer._internal.bindings')
local git = require('kago.explorer.git')
local filter = require('kago.explorer.filter')
local preview = require('kago.explorer.preview')

---@class kago.explorer.Entry
---@field path string
---@field name string
---@field dir boolean
---@field link boolean
---@field depth integer
---@field name_col integer?
---@field name_end integer?

---@class kago.explorer.State
---@field root string
---@field expanded table<string, boolean>
---@field entries kago.explorer.Entry[]
---@field hidden boolean
---@field selected string
---@field win integer?
---@field buf integer?
---@field target integer?
---@field git_status table<string, string>?
---@field git_cancel fun()?
---@field filter kago.explorer.Filter?
---@field filter_selected string?
---@field preview kago.explorer.Preview?

---@type table<integer, kago.explorer.State?>
local states = {}

local function notify(err)
  vim.notify('explorer: ' .. tostring(err), vim.log.levels.WARN)
end

---@param state kago.explorer.State
local function visible(state)
  return state.win ~= nil
    and vim.api.nvim_win_is_valid(state.win)
    and state.buf ~= nil
    and vim.api.nvim_buf_is_valid(state.buf)
    and vim.api.nvim_win_get_buf(state.win) == state.buf
end

---@param state kago.explorer.State
local function current(state)
  if visible(state) then
    return state.entries[vim.api.nvim_win_get_cursor(assert(state.win))[1]]
  end
end

---@param state kago.explorer.State
local function remember(state)
  local entry = current(state)
  if entry then
    state.selected = entry.path
  end
end

---@param state kago.explorer.State
local function update_preview(state)
  if not state.preview then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if visible(state) and (win == state.win or (state.filter and win == state.filter.input_win)) then
    state.preview:update(assert(state.win), current(state))
  else
    state.preview:hide()
  end
end

---@param state kago.explorer.State
local function refresh_git(state)
  if state.git_cancel then
    state.git_cancel()
  end
  state.git_cancel = git.fetch(state.root, function(statuses, err)
    state.git_cancel = nil
    state.git_status = statuses
    view.render_git(state)
    if err then
      notify(err)
    end
  end)
end

---@param state kago.explorer.State
local function reset_filter(state)
  if state.filter then
    state.filter:dispose()
  end
  if state.filter_selected then
    state.selected = state.filter_selected
    state.filter_selected = nil
  end
end

---@param state kago.explorer.State
local function release(state)
  state.win, state.buf = nil, nil
  reset_filter(state)
  if state.preview then
    state.preview:hide()
  end
  if state.git_cancel then
    state.git_cancel()
    state.git_cancel = nil
  end
end

---@param state kago.explorer.State
local function render(state)
  state.entries = entries.collect(state, notify)
  view.render(state)
  remember(state)
  update_preview(state)
end

---@param state kago.explorer.State
---@param confirm fun()
local function open_filter(state, confirm)
  if not state.filter then
    state.filter = filter.new(function(search)
      if not visible(state) then
        return
      end
      if search.query ~= '' then
        if not state.filter_selected then
          remember(state)
          state.filter_selected = state.selected
        end
        if not search.matches[state.selected] then
          state.selected = search.first or state.root
        end
      elseif state.filter_selected then
        state.selected = state.filter_selected
        state.filter_selected = nil
      end
      render(state)
    end)
  end
  local search = state.filter
  if search.root ~= state.root or search.hidden ~= state.hidden then
    search:reload(state.root, state.hidden)
  end
  search:open_input(assert(state.win), {
    confirm = confirm,
    move = function(delta)
      local win = assert(state.win)
      local row = vim.api.nvim_win_get_cursor(win)[1]
      local first = #state.entries > 1 and 2 or 1
      row = math.max(first, math.min(#state.entries, row + delta))
      vim.api.nvim_win_set_cursor(win, { row, 0 })
      remember(state)
      update_preview(state)
    end,
  })
  update_preview(state)
end

---@param state kago.explorer.State
---@param path string
local function change_root(state, path)
  local stat, err = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'directory' then
    notify(err or ('Not a directory: ' .. path))
    return false
  end
  if state.root ~= path then
    reset_filter(state)
    state.git_status = nil
  end
  state.root = path
  if visible(state) then
    refresh_git(state)
  end
  return true
end

---@param state kago.explorer.State
local function accept(state)
  local entry = current(state)
  if not entry then
    return
  end
  if entry.dir then
    if state.filter and state.filter.query ~= '' then
      reset_filter(state)
      local path = entry.path
      while path ~= state.root do
        state.expanded[path] = true
        local parent = vim.fs.dirname(path)
        if not parent or parent == path then
          break
        end
        path = parent
      end
      state.selected = entry.path
      render(state)
      return
    end
    if entry.path ~= state.root then
      state.expanded[entry.path] = not state.expanded[entry.path]
      remember(state)
      render(state)
    end
    return
  end
  local stat, err = vim.uv.fs_stat(entry.path)
  if not stat or stat.type ~= 'file' then
    notify(err or ('Not a regular file: ' .. entry.path))
    return
  end
  local target = state.target
  if
    not target
    or not vim.api.nvim_win_is_valid(target)
    or vim.api.nvim_win_get_tabpage(target) ~= vim.api.nvim_get_current_tabpage()
    or vim.bo[vim.api.nvim_win_get_buf(target)].buftype ~= ''
  then
    vim.cmd('rightbelow vnew')
    target = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(assert(state.win), 32)
  end
  state.target = target
  vim.api.nvim_set_current_win(target)
  if vim.api.nvim_buf_get_name(0) == entry.path then
    return
  end
  local ok, open_err = pcall(vim.cmd.edit, { args = { entry.path }, magic = { file = false } })
  if not ok then
    notify(open_err)
    vim.api.nvim_set_current_win(assert(state.win))
  end
end

---@param state kago.explorer.State
---@return kago.explorer.Actions
local function build_actions(state)
  return {
    accept = function()
      accept(state)
    end,
    collapse = function()
      local entry = current(state)
      if not entry then
        return
      end
      if
        entry.dir
        and state.expanded[entry.path]
        and not (state.filter and state.filter.query ~= '')
      then
        state.expanded[entry.path] = nil
        state.selected = entry.path
      else
        state.selected = vim.fs.dirname(entry.path) or state.root
      end
      render(state)
    end,
    parent_root = function()
      local old = state.root
      if change_root(state, vim.fs.dirname(old) or old) then
        state.selected = old
        render(state)
      end
    end,
    set_root = function()
      local entry = current(state)
      if entry and entry.dir and change_root(state, entry.path) then
        state.selected = entry.path
        render(state)
      end
    end,
    toggle_hidden = function()
      remember(state)
      state.hidden = not state.hidden
      if state.filter then
        state.filter:reload(state.root, state.hidden)
      end
      render(state)
    end,
    refresh = function()
      remember(state)
      if state.preview then
        state.preview:hide()
      end
      if state.filter then
        state.filter:reload(state.root, state.hidden)
      end
      render(state)
      refresh_git(state)
    end,
    toggle_preview = function()
      state.preview = state.preview or preview.new()
      state.preview.enabled = not state.preview.enabled
      update_preview(state)
    end,
    scroll = function(delta, key)
      if state.preview and state.preview.enabled then
        state.preview:scroll(delta)
      else
        vim.cmd.normal({
          args = { vim.api.nvim_replace_termcodes(key, true, false, true) },
          bang = true,
        })
      end
    end,
    filter = function()
      open_filter(state, function()
        accept(state)
      end)
    end,
    clear_filter = function()
      reset_filter(state)
      render(state)
    end,
    close = M.close,
  }
end

---@param opts? { root?: string }
function M.open(opts)
  local tab = vim.api.nvim_get_current_tabpage()
  local state = states[tab]
  local root = vim.fs.normalize(vim.fn.fnamemodify(opts and opts.root or vim.fn.getcwd(), ':p'))
  if not state then
    state = { root = root, expanded = {}, entries = {}, hidden = false, selected = root }
    if not change_root(state, root) then
      return
    end
    local file = vim.api.nvim_buf_get_name(0)
    local parent = vim.fs.dirname(file)
    local ancestors = {}
    while parent and parent ~= state.root do
      ancestors[#ancestors + 1] = parent
      local next_parent = vim.fs.dirname(parent)
      if next_parent == parent then
        break
      end
      parent = next_parent
    end
    if parent == state.root then
      state.selected = file
      for _, path in ipairs(ancestors) do
        state.expanded[path] = true
      end
    end
    states[tab] = state
  elseif opts and opts.root then
    if not change_root(state, root) then
      return
    end
    state.selected = root
  end
  if visible(state) then
    vim.api.nvim_set_current_win(assert(state.win))
    render(state)
    refresh_git(state)
    return
  end
  release(state)
  local target = vim.api.nvim_get_current_win()
  if vim.bo.buftype == '' then
    state.target = target
  end
  local edit_target = state.target
  local buf = vim.api.nvim_create_buf(false, true)
  state.buf = buf
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'kago-explorer'
  vim.cmd('topleft 32vsplit')
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, buf)
  -- WinEnter sees the copied editing buffer before the split receives its scratch buffer.
  state.target = edit_target
  local wo = vim.wo[state.win]
  wo.number = false
  wo.relativenumber = false
  wo.wrap = false
  wo.cursorline = true
  wo.signcolumn = 'no'
  wo.foldcolumn = '0'
  wo.winfixwidth = true
  wo.spell = false
  wo.list = false
  bindings.bind(buf, build_actions(state))
  render(state)
  refresh_git(state)
end

function M.close()
  local state = states[vim.api.nvim_get_current_tabpage()]
  if not state then
    return
  end
  if not visible(state) then
    release(state)
    return
  end
  remember(state)
  reset_filter(state)
  if state.preview then
    state.preview:hide()
  end
  if state.git_cancel then
    state.git_cancel()
    state.git_cancel = nil
  end
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    vim.cmd('rightbelow vnew')
  end
  vim.api.nvim_win_close(assert(state.win), false)
  state.win, state.buf = nil, nil
end

function M.toggle()
  local state = states[vim.api.nvim_get_current_tabpage()]
  if state and visible(state) then
    M.close()
  else
    M.open()
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('kago-explorer', { clear = true })
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function()
      for _, state in pairs(states) do
        if state and visible(state) then
          refresh_git(state)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(ev)
      for _, state in pairs(states) do
        if state and state.win == tonumber(ev.match) then
          release(state)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = group,
    callback = function(ev)
      for _, state in pairs(states) do
        if state.buf == ev.buf then
          vim.schedule(function()
            if state.buf == ev.buf and not visible(state) then
              release(state)
            end
          end)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinResized', {
    group = group,
    callback = function()
      for _, state in pairs(states) do
        local input_win = state and state.filter and state.filter.input_win
        if state and visible(state) and input_win and vim.api.nvim_win_is_valid(input_win) then
          vim.api.nvim_win_set_width(input_win, vim.api.nvim_win_get_width(assert(state.win)))
        end
        update_preview(state)
      end
    end,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    callback = function()
      local state = states[vim.api.nvim_get_current_tabpage()]
      if state and state.win == vim.api.nvim_get_current_win() then
        remember(state)
        update_preview(state)
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = group,
    callback = function()
      local state = states[vim.api.nvim_get_current_tabpage()]
      if state and vim.bo.buftype == '' then
        state.target = vim.api.nvim_get_current_win()
      end
      vim.schedule(function()
        for _, entry in pairs(states) do
          update_preview(entry)
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd('TabClosed', {
    group = group,
    callback = function()
      for tab in pairs(states) do
        if not vim.api.nvim_tabpage_is_valid(tab) then
          local state = states[tab]
          if state then
            reset_filter(state)
            if state.preview then
              state.preview:hide()
            end
          end
          if state and state.git_cancel then
            state.git_cancel()
          end
          states[tab] = nil
        end
      end
    end,
  })
end

return M
