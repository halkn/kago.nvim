local M = {}
local icon_ns = vim.api.nvim_create_namespace('kago_explorer_icons')
local git = require('kago.explorer.git')
local git_ns = vim.api.nvim_create_namespace('kago_explorer_git')

local function file_icon(name)
  local ok, icons = pcall(require, 'nvim-web-devicons')
  if ok then
    local icon, hl = icons.get_icon(name, vim.fn.fnamemodify(name, ':e'), { default = true })
    return icon or '', hl or 'Normal'
  end
  return '', 'Normal'
end

---@param state kago.explorer.State
function M.render_git(state)
  local buf = state.buf
  local win = state.win
  if
    not win
    or not vim.api.nvim_win_is_valid(win)
    or not buf
    or not vim.api.nvim_buf_is_valid(buf)
    or vim.api.nvim_win_get_buf(win) ~= buf
  then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, git_ns, 0, -1)
  for row, entry in ipairs(state.entries) do
    local status = state.git_status and git.status(state.git_status, entry.path)
    if status and status ~= '  ' then
      vim.api.nvim_buf_set_extmark(buf, git_ns, row - 1, 0, {
        virt_text = git.chunks(status),
        virt_text_pos = 'right_align',
        hl_mode = 'combine',
      })
      if status == '!!' then
        -- The root row carries no name range, and while filtering it holds the query
        -- header rather than the root path, so fall back to the rendered line.
        local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
        vim.api.nvim_buf_set_extmark(buf, git_ns, row - 1, entry.name_col or 0, {
          end_col = entry.name_end or #line,
          hl_group = 'NonText',
        })
      end
    end
  end
end

---@param state kago.explorer.State
function M.render(state)
  local buf, win = assert(state.buf), assert(state.win)
  local entries = state.entries
  local lines = { state.root }
  local search = state.filter
  local filtering = search and search.query ~= ''
  if search and filtering then
    local status = search.error
      or (search.loading and 'searching…' or (search.count .. ' matches'))
    lines[1] = '/' .. search.query:gsub('[%c]', ' ') .. ' [' .. status:gsub('[%c]', ' ') .. ']'
  end
  local highlights = {}
  for row, entry in ipairs(entries) do
    if row > 1 then
      local expanded = filtering or state.expanded[entry.path]
      local marker = entry.dir and (expanded and '▾ ' or '▸ ') or '  '
      local name = entry.name:gsub('[%c]', function(c)
        return string.format('\\x%02x', c:byte())
      end)
      local icon, hl
      if entry.dir then
        icon, hl = expanded and '' or '', 'Directory'
      else
        icon, hl = file_icon(entry.name)
      end
      local prefix = string.rep('  ', entry.depth - 1) .. marker
      entry.name_col = #prefix + #icon + 1
      entry.name_end = entry.name_col + #name
      highlights[#highlights + 1] = {
        row = #lines,
        col = #prefix,
        end_col = #prefix + #icon,
        hl = hl,
      }
      lines[#lines + 1] = prefix .. icon .. ' ' .. name .. (entry.link and ' @' or '')
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, icon_ns, 0, -1)
  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(buf, icon_ns, highlight.row, highlight.col, {
      end_col = highlight.end_col,
      hl_group = highlight.hl,
    })
  end
  local selected = state.selected
  local row = 1
  while true do
    local found = false
    for i, entry in ipairs(entries) do
      if entry.path == selected then
        row, found = i, true
        break
      end
    end
    local parent = vim.fs.dirname(selected)
    if found or not parent or parent == selected then
      break
    end
    selected = parent
  end
  vim.api.nvim_win_set_cursor(win, { row, 0 })
  M.render_git(state)
end

return M
