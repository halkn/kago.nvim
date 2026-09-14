local target = arg[1] or 'tests'
if vim.fn.isdirectory(target) == 0 then
  assert(vim.fn.filereadable(target) == 1, 'Test file does not exist: ' .. target)
  assert(target:match('_spec%.lua$'), 'Expected a *_spec.lua test file')
  require('plenary.busted').run(target)
else
  assert(#vim.fn.glob(target .. '/**/*_spec.lua', false, true) > 0, 'No specs found: ' .. target)
  require('plenary.test_harness').test_directory(target, {
    minimal_init = 'tests/minimal_init.lua',
    sequential = true,
    keep_going = true,
    timeout = 60000,
  })
end
