local M = {}

local icon_fn = nil

function M.get_icon(filepath, is_dir)
  if icon_fn == false then
    return nil
  end
  if icon_fn == nil then
    local ok, icons = pcall(require, 'mini.icons')
    if ok and icons.get then
      if not icons.config then
        pcall(icons.setup, {})
      end
      icon_fn = function(p, dir)
        local cat = dir and 'directory' or 'file'
        local ok2, icon = pcall(icons.get, cat, p)
        if ok2 and icon and icon ~= '' then
          return icon
        end
        return nil
      end
    else
      local ok2, devicons = pcall(require, 'nvim-web-devicons')
      if ok2 then
        icon_fn = function(p, dir)
          if dir then
            return '\xef\x81\xbb'
          end
          local ext = vim.fn.fnamemodify(p, ':e')
          return devicons.get_icon(p, ext)
        end
      else
        icon_fn = false
        return nil
      end
    end
  end
  return icon_fn(filepath, is_dir)
end

return M
