" Headlights is a Vim plugin that helps you manage your plugins (bundles). See
" README.mkd for details.

" NOTE: You may override the below default settings in your vimrc (anything
" with a 'g:' prefix
if has("gui_running")
  " The menu root. If you don't want an extra menu, set this to the default
  " "Plugin" menu or a submenu thereof (eg. "Plugin.Headlights").
  let g:headlights_root = "Bundle"

  " Categorise menu items alphabetically (1 to enable, 0 to disable)
  let g:headlights_spillover = 1

  " The character limit after which characters are truncated
  "let g:headlights_trunclimit = 20

  " The threshhold after which the menu is categorised
  let g:headlights_threshhold = 30

  " A separator that precedes the menu (for eg. when reusing the "Plugin" menu)
  let g:headlights_topseparator = 0

  " enable this to debug any errors or performance issues. run the :messages
  " command in Vim to find the location of the log file.
  " IMPORTANT: set this to 0 when you're done, otherwise log files will be
  " generated every time you load a Vim instance.
  let g:headlights_debug = 0

  " NOTE: functions and autocmds are disabled until further notice
  let g:headlights_commands = 1
  let g:headlights_mappings = 1
  let g:headlights_abbreviations = 1
  let g:headlights_functions = 0
  let g:headlights_autocmds = 0

  " add a menu placeholder
  execute "amenu " . g:headlights_root . ".Reveal :call <SID>MakeMenu()<cr>"

  " define menu command
  command! HeadlightsTurnOn call <SID>MakeMenu()
endif

function! l:GetCommandOutput(command)
  redir => l:out
  execute "silent verbose " . a:command
  redir END
  return l:out
endfunction

function! l:InitComponents()
  " components are disabled by default
  let s:commands = ""
  let s:mappings = ""
  let s:functions = ""
  let s:abbreviations = ""
  let s:autocmds = ""

  let s:scriptnames = l:GetCommandOutput("scriptnames")

  if (g:headlights_commands)
    let s:commands = l:GetCommandOutput("command")
  endif

  if (g:headlights_mappings)
    let s:mappings = l:GetCommandOutput("map")
  endif

  if (g:headlights_functions)
    let s:functions = l:GetCommandOutput("function")
  endif

  if (g:headlights_abbreviations)
    let s:abbreviations = l:GetCommandOutput("abbreviate")
  endif

  if (has("autocmd") && g:headlights_autocmds)
    let s:autocmds = l:GetCommandOutput("autocmd")
  endif
endfunction

function! s:MakeMenu()
  call l:InitComponents()

  " load assisting python script
  let l:scriptdir = matchlist(s:scriptnames, '\d\+:\s\+\([^ ]\+\)headlights.vim')[1]
  execute "pyfile " . l:scriptdir . "headlights.py"

  " remove menu placeholder
  execute "aunmenu " . g:headlights_root . ".Reveal"

  " add menu separator (per global option)
  if (g:headlights_topseparator)
    execute "amenu " . g:headlights_root . ".-Sep1- :"
  endif

  " local python kept intentionally minimal
  python << endpython

import vim, time

#timer_start = time.time()

headlights = Headlights(
    root=vim.eval("g:headlights_root"),
    spillover=int(vim.eval("g:headlights_spillover")),
    threshhold=int(vim.eval("g:headlights_threshhold")),
    debug=bool(int(vim.eval("g:headlights_debug"))),
    timer_start=time.time())

try:
  log_name, menu_commands = headlights.get_menu_commands(
      scriptnames=vim.eval("s:scriptnames"),
      commands=vim.eval("s:commands"),
      mappings=vim.eval("s:mappings"),
      abbreviations=vim.eval("s:abbreviations"),
      functions=vim.eval("s:functions"),
      autocmds=vim.eval("s:autocmds"))

  [vim.command(menu_cmd) for menu_cmd in menu_commands]

  if log_name:
      vim.command("echomsg('Headlights log file: %s')" % log_name)

except Exception, e:
    vim.command("echoerr(\"Headlights exception: %s\")" % str(e).replace("'", "\\'"))
    pass

endpython

endfunction
