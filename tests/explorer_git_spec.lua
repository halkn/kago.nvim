---@type fun(expected: any, actual: any, message?: string)
local eq = require('luassert').same

local git = require('kago.explorer.git')
local explorer = require('kago.explorer')
explorer.setup()

---@type string
local root

local function command(args)
  local cmd = { 'git', '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false' }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { cwd = root }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end

local function fetch(path)
  ---@type table<string, string>?
  local result
  ---@type string?
  local failure
  git.fetch(path, function(status, err)
    result, failure = status, err
  end)
  assert(
    vim.wait(10000, function()
      return result ~= nil
    end),
    'git fetch timed out'
  )
  assert(not failure, failure)
  return assert(result)
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

describe('explorer git', function()
  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, 'p')
    root = assert(vim.uv.fs_realpath(root))
  end)

  after_each(function()
    explorer.close()
    vim.cmd('stopinsert')
    vim.cmd('silent! only!')
    vim.cmd('silent! %bwipeout!')
    vim.fn.delete(root, 'rf')
  end)

  it('parses porcelain statuses, renames, ignored paths and conflicts', function()
    local parsed = git.parse(
      root,
      table.concat({
        'MM dir/日本 語.txt',
        ' D deleted/a.txt',
        'R  renamed/new.txt',
        'old/ M tricky\nname.txt',
        '?? unknown/line\nbreak.txt',
        '!! ignored.txt',
        'A  added.txt',
        '',
      }, '\0')
    )
    eq('MM', parsed[root .. '/dir/日本 語.txt'])
    eq('MM', parsed[root .. '/dir'])
    eq(' D', parsed[root .. '/deleted'])
    eq('R ', parsed[root .. '/renamed/new.txt'])
    eq('R ', parsed[root .. '/old'])
    eq(' ?', parsed[root .. '/unknown/line\nbreak.txt'])
    eq('!!', parsed[root .. '/ignored.txt'])
    local ignored = git.parse(root, '!! cache/\0!! logs/debug.log\0')
    assert(ignored[root] == nil and ignored[root .. '/logs'] == nil)
    eq('!!', git.status(ignored, root .. '/cache/nested/日本 語.txt'))
    eq(nil, (git.status(ignored, root .. '/cache-other/file.txt')))
    eq('A ', parsed[root .. '/added.txt'])
    eq('RD', parsed[root])
    for _, xy in ipairs({ 'DD', 'AU', 'UD', 'UA', 'DU', 'AA', 'UU' }) do
      eq('UU', git.parse(root, xy .. ' conflict.txt\0')[root .. '/conflict.txt'])
    end
  end)

  it('refreshes Git decorations and ignored descendants in a real repository', function()
    assert(next(fetch(root)) == nil, 'non-repository should have no status')
    command({ 'init', '-q' })
    vim.fn.mkdir(root .. '/dir', 'p')
    vim.fn.writefile({ 'base' }, root .. '/dir/file.txt')
    vim.fn.writefile({ 'remove' }, root .. '/dir/deleted.txt')
    vim.fn.writefile({ 'rename' }, root .. '/old.txt')
    command({ 'add', '.' })
    command({
      '-c',
      'user.name=Explorer Test',
      '-c',
      'user.email=test@example.invalid',
      'commit',
      '-qm',
      'fixture',
    })
    assert(next(fetch(root)) == nil, 'clean repository should have no status')
    vim.fn.writefile({ 'staged' }, root .. '/dir/file.txt')
    command({ 'add', 'dir/file.txt' })
    vim.fn.writefile({ 'unstaged' }, root .. '/dir/file.txt')
    vim.fn.delete(root .. '/dir/deleted.txt')
    command({ 'mv', 'old.txt', '日本 語\nnew.txt' })
    vim.fn.writefile({}, root .. '/untracked.txt')
    local statuses = fetch(root .. '/dir')
    eq('MM', statuses[root .. '/dir/file.txt'])
    eq('MD', statuses[root .. '/dir'])
    eq('R ', statuses[root .. '/日本 語\nnew.txt'])
    eq(' ?', statuses[root .. '/untracked.txt'])

    explorer.open({ root = root })
    local buf = vim.api.nvim_get_current_buf()
    local ns = vim.api.nvim_get_namespaces().kago_explorer_git
    local function marks()
      return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
    end
    assert(vim.wait(10000, function()
      return #marks() > 0
    end))
    local first = assert(marks()[1])
    eq('right_align', assert(first[4]).virt_text_pos)
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    feed('l')
    local found = false
    for _, mark in ipairs(marks()) do
      local line = assert(vim.api.nvim_buf_get_lines(buf, mark[2], mark[2] + 1, false)[1])
      if line:find('file.txt', 1, true) then
        local chunks = assert(assert(mark[4]).virt_text)
        assert(assert(chunks[1])[1] == '●' and assert(chunks[3])[1] == '●')
        found = true
      end
    end
    assert(found, 'expanded file should receive both status icons')
    local selected = vim.api.nvim_get_current_line()
    command({ 'add', '.' })
    command({
      '-c',
      'user.name=Explorer Test',
      '-c',
      'user.email=test@example.invalid',
      'commit',
      '-qm',
      'changes',
    })
    feed('u')
    assert(
      vim.wait(10000, function()
        return #marks() == 0
      end),
      'refresh should clear old decorations'
    )
    assert(vim.api.nvim_get_current_line() == selected, 'git refresh moved cursor')
    local target = vim.api.nvim_get_current_win()
    vim.cmd('wincmd p')
    vim.cmd.edit(root .. '/dir/file.txt')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'saved change' })
    vim.cmd.write()
    assert(
      vim.wait(10000, function()
        return #marks() > 0
      end),
      'saving should refresh status'
    )
    assert(vim.api.nvim_get_current_win() ~= target, 'refresh stole focus')
    explorer.close()

    vim.fn.mkdir(root .. '/cache/nested', 'p')
    vim.fn.writefile({}, root .. '/cache/nested/日本 語.txt')
    vim.fn.writefile({}, root .. '/debug.log')
    vim.fn.writefile({}, root .. '/keep.log')
    vim.fn.writefile({}, root .. '/excluded.txt')
    vim.fn.writefile({ 'excluded.txt' }, root .. '/.git/info/exclude')
    vim.fn.writefile({ 'cache/', '*.log', '!keep.log', 'dir/file.txt' }, root .. '/.gitignore')
    local ignored_status = fetch(root)
    eq('!!', ignored_status[root .. '/cache'])
    eq('!!', ignored_status[root .. '/debug.log'])
    eq('!!', ignored_status[root .. '/excluded.txt'])
    eq(' ?', ignored_status[root .. '/keep.log'])
    assert(ignored_status[root .. '/dir/file.txt'] == ' M', 'tracked file must retain Git status')
    explorer.open({ root = root .. '/cache' })
    buf = vim.api.nvim_get_current_buf()
    assert(vim.wait(10000, function()
      return #marks() > 0
    end))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    feed('l')
    local dimmed, marked = false, false
    for _, mark in ipairs(marks()) do
      local line = assert(vim.api.nvim_buf_get_lines(buf, mark[2], mark[2] + 1, false)[1])
      local details = assert(mark[4])
      if line:find('日本 語.txt', 1, true) then
        if details.hl_group then
          eq('NonText', details.hl_group)
          eq('日本 語.txt', line:sub(mark[3] + 1, details.end_col))
          dimmed = true
        elseif details.virt_text then
          eq('◌', assert(details.virt_text[2])[1])
          marked = true
        end
      end
    end
    assert(dimmed and marked, 'ignored descendants need dimmed names and markers')
    feed('/日本<Esc>')
    assert(vim.wait(10000, function()
      return assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]):find('1 matches', 1, true)
        ~= nil
    end))
    local below_root = false
    for _, mark in ipairs(marks()) do
      below_root = below_root or mark[2] > 0
    end
    assert(below_root, 'filtering an ignored root must keep decorating the entries below it')
    feed('<Esc>')
    vim.fn.writefile({}, root .. '/.gitignore')
    feed('u')
    assert(
      vim.wait(10000, function()
        for _, mark in ipairs(marks()) do
          if assert(mark[4]).hl_group then
            return false
          end
        end
        return #marks() > 0
      end),
      'refresh must remove ignored name highlights'
    )
    explorer.close()
  end)

  it('cancels a repository lookup', function()
    local called = false
    local cancel = git.fetch(root, function()
      called = true
    end)
    cancel()
    vim.wait(200)
    assert(not called, 'cancelled fetch delivered stale result')
  end)

  it('cancels an in-flight status process without delivering stale data', function()
    local original_system = vim.system
    local pending = {}
    local killed = 0
    vim.system = function(_, _, callback)
      pending[#pending + 1] = callback
      return {
        kill = function()
          killed = killed + 1
        end,
      }
    end
    local ok, err = pcall(function()
      local delivered = false
      local stop = git.fetch(root, function()
        delivered = true
      end)
      pending[1]({ code = 0, stdout = root .. '\n' })
      vim.wait(100, function()
        return #pending == 2
      end)
      stop()
      pending[2]({ code = 0, stdout = ' M stale.txt\0' })
      vim.wait(50)
      assert(killed == 1 and not delivered, 'cancelled status process delivered stale data')
    end)
    vim.system = original_system
    assert(ok, err)
  end)
end)
