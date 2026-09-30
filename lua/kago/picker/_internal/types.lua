---@alias kago.picker.Split 'split'|'vsplit'

---@alias kago.picker.Job { kill: fun(self: any, signal: integer): any }

---@class kago.picker.TreeNode
---@field name string
---@field path string
---@field is_dir boolean
---@field children kago.picker.TreeNode[]?

---@class kago.picker.Item
---@field text string
---@field display string?
---@field _match_pos integer[]?
---@field buf integer?
---@field lnum integer?
---@field path string?
---@field _tree_node kago.picker.TreeNode?
---@field value any
---@field index integer?

---@class kago.picker.GitItem: kago.picker.Item
---@field path string

---@class kago.picker.SourceOptions
---@field origin_buf integer?
---@field no_ignore boolean?
---@field scope 'branch'|'worktree'?
---@field [string] any

---@class kago.picker.OpenOptions
---@field title string?
---@field items kago.picker.Item[]?
---@field on_select fun(item: kago.picker.Item)?
---@field on_cancel fun()?

---@class kago.picker.Source
---@field name string
---@field load fun(config: kago.picker.Config, opts: kago.picker.SourceOptions, callback: fun(items: kago.picker.Item[])): kago.picker.Job?
---@field use_preview boolean?
---@field filter? fun(items: kago.picker.Item[], query: string): kago.picker.Item[]
---@field footer string?
---@field title? fun(opts: kago.picker.SourceOptions): string
---@field keymaps table<string, fun(ctx: kago.picker.SourceContext)>?
---@field debounce_query boolean?
---@field on_open fun(ctx: kago.picker.SourceContext)?
---@field on_close fun()?
---@field on_query_change fun(query: string, ctx: kago.picker.SourceContext)?
---@field on_accept fun(item: kago.picker.Item)?
---@field on_accept_split fun(item: kago.picker.Item, split_cmd: kago.picker.Split, origin_buf: integer?)?
---@field preview_file? fun(item: kago.picker.Item): string?, integer?
---@field update_preview? fun(item: kago.picker.Item, show: fun(path: string, lnum: integer?)): 'clear'|nil
---@field match_highlight_offset? fun(): integer

---@class kago.picker.SourceContext
---@field list_buf integer
---@field set_items fun(all: kago.picker.Item[], filtered: kago.picker.Item[])
---@field set_job fun(job: kago.picker.Job?)
---@field cancel_job fun()
---@field is_current_job fun(job: kago.picker.Job?): boolean
---@field set_cursor_idx fun(idx: integer)
---@field clamp_cursor fun()
---@field get_current_item fun(): kago.picker.Item?
---@field render fun()
---@field update_cursor fun()
---@field update_preview fun()
---@field move_cursor fun(delta: integer)
---@field accept fun()
---@field accept_split fun(split_cmd: kago.picker.Split)
---@field close fun()
---@field jump_to_text fun(text: string)
---@field focus_list fun()
---@field focus_prompt fun()
---@field switch_source fun(name: string)
---@field get_opt fun(key: string): any
---@field set_opt fun(key: string, value: any)
---@field reload fun()
---@field set_on_esc fun(callback: fun())
---@field set_on_cursor_moved fun(callback: fun(idx: integer))

---@alias kago.picker.PreviewState { preview_buf: integer?, preview_win: integer? }

return {}
