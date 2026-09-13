local M = {}

local original_ui_select = vim.ui.select

function M.open(open, items, opts, on_choice)
  if type(opts) == 'function' and on_choice == nil then
    on_choice = opts
    opts = nil
  end
  opts = opts or {}
  on_choice = on_choice or function() end

  if type(items) ~= 'table' then
    return original_ui_select(items, opts, on_choice)
  end

  local picker_items = {}
  for i, item in ipairs(items) do
    picker_items[i] = { text = (opts.format_item or tostring)(item), value = item, index = i }
  end

  -- vim.ui.select promises exactly one call, with nil when the user cancels.
  local finished = false
  local function choose(...)
    if finished then
      return
    end
    finished = true
    on_choice(...)
  end
  return open('select', {
    title = opts.prompt or 'select',
    items = picker_items,
    on_select = function(picked)
      if picked then
        choose(picked.value, picked.index)
      else
        choose(nil)
      end
    end,
    on_cancel = function()
      choose(nil)
    end,
  })
end

return M
