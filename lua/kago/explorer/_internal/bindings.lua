local M = {}

---@class kago.explorer.Actions
---@field accept fun()
---@field collapse fun()
---@field parent_root fun()
---@field set_root fun()
---@field toggle_hidden fun()
---@field refresh fun()
---@field toggle_preview fun()
---@field scroll fun(delta: integer, key: string)
---@field filter fun()
---@field clear_filter fun()
---@field close fun()

---@param buf integer
---@param actions kago.explorer.Actions
function M.bind(buf, actions)
  local function map(key, callback, desc)
    vim.keymap.set('n', key, callback, { buffer = buf, silent = true, desc = desc })
  end
  map('j', 'j', 'Next entry')
  map('k', 'k', 'Previous entry')
  for _, key in ipairs({ '<CR>', 'l' }) do
    map(key, actions.accept, 'Open file or toggle directory')
  end
  map('h', actions.collapse, 'Collapse directory or select parent')
  map('<BS>', actions.parent_root, 'Go to parent root')
  map('.', actions.set_root, 'Set explorer root')
  map('H', actions.toggle_hidden, 'Toggle hidden files')
  map('u', actions.refresh, 'Refresh explorer')
  map('P', actions.toggle_preview, 'Toggle file preview')
  for key, delta in pairs({ ['<C-d>'] = 1, ['<C-u>'] = -1 }) do
    map(key, function()
      actions.scroll(delta, key)
    end, 'Scroll preview or explorer')
  end
  map('/', actions.filter, 'Filter explorer paths')
  map('<Esc>', actions.clear_filter, 'Clear explorer filter')
  map('q', actions.close, 'Close explorer')
end

return M
