local M = {}

---@param path string
---@param split_cmd? 'split'|'vsplit'
---@param lnum? integer
function M.open(path, split_cmd, lnum)
  vim.cmd[split_cmd or 'edit']({ args = { path }, magic = { file = false } })
  if lnum then
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  end
end

return M
