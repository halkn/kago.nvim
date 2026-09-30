local file_open = require('kago.picker._internal.open')
---@class kago.picker.SelectSource: kago.picker.Source
local source = {
  name = 'select',
  use_preview = false,
}

function source.load(_, _, callback)
  vim.schedule(function()
    callback({})
  end)
  return nil
end

function source.on_accept(item)
  file_open.open(item.text)
end

function source.on_accept_split(item, split_cmd)
  file_open.open(item.text, split_cmd)
end

return source
