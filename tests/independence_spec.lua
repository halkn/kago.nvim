-- Requiring one module must not drag in an unrelated one, so each module is loaded in a
-- subprocess: package.loaded is global and a single Neovim could only ever check the first.
local modules = {
  'explorer',
  'picker',
  'input',
  'notify',
  'terminal',
  'yankring',
  'surround',
  'pairs',
  'replace',
}

local probe = table.concat({
  "require('kago.%s')",
  'local loaded = {}',
  "for name in pairs(package.loaded) do if name:match('^kago%%.') then loaded[#loaded + 1] = name end end",
  'table.sort(loaded)',
  "io.write(table.concat(loaded, ' '))",
}, ' ')

---@param name string
---@return string[]
local function loaded_by(name)
  local out = vim
    .system({
      vim.v.progpath,
      '--clean',
      '--headless',
      '-n',
      '-i',
      'NONE',
      '--cmd',
      'set runtimepath^=' .. vim.fn.getcwd(),
      '-c',
      'lua ' .. probe:format(name),
      '-c',
      'qa!',
    }, { env = { NVIM_LOG_FILE = '/dev/null' }, text = true })
    :wait()
  assert(out.code == 0, name .. ': ' .. (out.stderr or ''))
  local stdout = out.stdout or ''
  return vim.split(vim.trim(stdout), ' ', { trimempty = true })
end

describe('module independence', function()
  for _, name in ipairs(modules) do
    it('loads ' .. name .. ' without unrelated modules', function()
      local prefix = 'kago.' .. name
      for _, found in ipairs(loaded_by(name)) do
        assert(
          found == prefix or found:find(prefix .. '.', 1, true) == 1,
          ('require("%s") also loaded %s'):format(prefix, found)
        )
      end
    end)
  end
end)
