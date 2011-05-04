" Headlights is a Vim plugin that provides a TextMate-like 'Bundles' menu. See
" README.mkd for details.

" TODO: change open behaviour so that it uses MacVim (if macvim is used), so that the file goes into the recent history
" raise a feature request with bjorn for that. also, will obey macvim's
" default file open settings. if you don't like that, change the preferences.
" that menu is just way too cluttered.
" TODO: also, for open in directory, definitely try and locate the file in
" Finder (if this is a mac), and do research on how to do that for windows
" (not a big deal though). also, have nerdtree, if nerdtree exists, and
" just use the standard bottom split -- keep it simple!
" TODO: fix the mode bug the dude got
" TODO: play around with mvim some more

" NOTE: You may override the below default settings in your vimrc (anything
" with a 'g:' prefix
if has("gui_running")
  " The menu root. If you want a separate menu, set this to another value such
  " as "Bundles", and set g:headlights_topseparator (below) to 0.
  let g:headlights_root = "Plugin"

  " A separator that precedes the menu (for eg. when reusing the "Plugin" menu)
  let g:headlights_topseparator = 1

  " Categorise menu items alphabetically (1 to enable, 0 to disable)
  let g:headlights_spillover = 1

  " The character limit after which characters are truncated
  "let g:headlights_trunclimit = 20

  " The threshhold after which the menu is categorised
  let g:headlights_threshhold = 30

  " enable this to debug any errors or performance issues. run the :messages
  " command in Vim to find the location of the log file.
  " IMPORTANT: set this to 0 when you're done, otherwise log files will be
  " generated every time you load a Vim instance.
  let g:headlights_debug = 1

  " NOTE: functions and autocmds are disabled until further notice
  let g:headlights_commands = 1
  let g:headlights_mappings = 1
  let g:headlights_abbreviations = 1
  let g:headlights_functions = 0
  let g:headlights_autocmds = 0

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

  " add menu separator (per global option)
  if (g:headlights_topseparator)
    execute "amenu " . g:headlights_root . ".-Sep1- :"
  endif

  " local python kept intentionally minimal
  python << endpython

import vim, time

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
