local M = {}

---@param state kago.explorer.State
---@param on_error fun(err: string?)
---@return kago.explorer.Entry[]
function M.collect(state, on_error)
  local entries = {
    { path = state.root, name = state.root, dir = true, link = false, depth = 0 },
  }
  local search = state.filter
  local filtering = search and search.query ~= ''
  ---@param path string
  ---@param depth integer
  local function scan(path, depth)
    local children = {}
    if search and filtering then
      children = search.children[path] or {}
    else
      local handle, err = vim.uv.fs_scandir(path)
      if not handle then
        on_error(err)
        return
      end
      while true do
        local name, kind = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end
        if state.hidden or name:sub(1, 1) ~= '.' then
          local child_path = vim.fs.joinpath(path, name)
          if not kind then
            local stat = vim.uv.fs_lstat(child_path)
            kind = stat and stat.type or 'unknown'
          end
          children[#children + 1] = {
            path = child_path,
            name = name,
            dir = kind == 'directory',
            link = kind == 'link',
            depth = depth,
          }
        end
      end
    end
    table.sort(children, function(a, b)
      if a.dir ~= b.dir then
        return a.dir
      end
      return a.name < b.name
    end)
    for _, child in ipairs(children) do
      local entry = vim.tbl_extend('force', {}, child, { depth = depth })
      entries[#entries + 1] = entry
      if entry.dir and (filtering or state.expanded[entry.path]) then
        scan(entry.path, depth + 1)
      end
    end
  end
  scan(state.root, 1)
  return entries
end

return M
