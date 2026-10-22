-- Read generated data only; theme directories cannot supply executable Lua.
local M = {}
local last
function M.apply(force)
  local path = vim.fn.expand('~/.config/themes/current/neovim.json')
  local file = io.open(path, 'r')
  if not file then return end
  local raw = file:read('*a'); file:close()
  if not force and raw == last then return end
  local ok, c = pcall(vim.json.decode, raw)
  if not ok or type(c) ~= 'table' then return end
  for _, key in ipairs({'background','text','cursor','selection','selection_text','comment','keyword','string','function','number','line_number','error','warning'}) do
    if type(c[key]) ~= 'string' or not c[key]:match('^#%x%x%x%x%x%x$') then return end
  end
  last = raw
  vim.opt.termguicolors = true
  vim.g.colors_name = 'syna'
  local function hl(names, value)
    for name in names:gmatch('%S+') do vim.api.nvim_set_hl(0, name, value) end
  end
  hl('Normal NormalNC NormalFloat SignColumn EndOfBuffer NeoTreeNormal NeoTreeNormalNC SnacksNormal', {fg=c.text,bg=c.background})
  hl('Cursor lCursor', {fg=c.background,bg=c.cursor})
  hl('Visual Search IncSearch CurSearch', {fg=c.selection_text,bg=c.selection})
  hl('LineNr FoldColumn', {fg=c.line_number,bg=c.background})
  hl('CursorLineNr', {fg=c.cursor,bold=true})
  hl('Comment @comment', {fg=c.comment,italic=true})
  hl('Keyword Statement Conditional Repeat Exception Operator @keyword', {fg=c.keyword})
  hl('String Character @string', {fg=c.string})
  hl('Function @function @function.call @method', {fg=c['function']})
  hl('Number Boolean Float Constant @number @boolean', {fg=c.number})
  hl('Type Identifier PreProc Special', {fg=c['function']})
  hl('DiagnosticError ErrorMsg', {fg=c.error})
  hl('DiagnosticWarn WarningMsg', {fg=c.warning})
  hl('DiagnosticInfo DiagnosticHint', {fg=c['function']})
  hl('DiagnosticUnderlineError', {sp=c.error,undercurl=true})
  hl('DiagnosticUnderlineWarn', {sp=c.warning,undercurl=true})
  hl('FloatBorder WinSeparator', {fg=c.comment,bg=c.background})
  hl('Pmenu StatusLine', {fg=c.text,bg=c.background})
  hl('PmenuSel', {fg=c.selection_text,bg=c.selection})
  vim.cmd('redraw')
end
function M.setup()
  local group = vim.api.nvim_create_augroup('SynaTheme', {clear=true})
  vim.api.nvim_create_autocmd({'FocusGained','BufEnter'}, {group=group,callback=function() M.apply(false) end})
  vim.api.nvim_create_autocmd({'VimEnter','ColorScheme'}, {group=group,callback=function() vim.schedule(function() M.apply(true) end) end})
  vim.api.nvim_create_user_command('SynaThemeReload',function() M.apply(true) end,{force=true})
  M.apply(true)
end
return M
