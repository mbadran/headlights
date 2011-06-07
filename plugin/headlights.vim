" Headlights is a Vim plugin that provides a TextMate-like 'Bundles' menu.
" Version: 1.1
" Maintainer:	Mohammed Badran <mebadran AT gmail>

" NOTE: You may override the below values in your vimrc
if !has('gui_running')
  finish
endif

" The menu root. You can set this to the name of an existing menu, such as
" 'Plugin'.
let g:headlights_root = 'Bundles'

" Alphabetic labeling of menu items
let g:headlights_spillover = 1

" The threshhold after which the menu is alphabetically labeled
let g:headlights_threshhold = 30

" Debug mode. Enable to debug any errors or performance issues.
" IMPORTANT: set this to 0 when you're done, otherwise log files will be
" generated every time you load a Vim instance.
let g:headlights_debug = 0

" Individual menu components. Enable or disable to preference. (Autocmds are
" broken and disabled by default.)
let g:headlights_commands = 1
let g:headlights_mappings = 1
let g:headlights_abbreviations = 1
let g:headlights_functions = 1
let g:headlights_autocmds = 0

autocmd GUIEnter * call s:AttachMenus()

" returns the output of a vim command
function! s:GetCommandOutput(command)
  " initialise to a blank value in case the command throws a vim error
  " (try-catch doesn't work properly here, for some reason)
  let l:out = ''

  redir => l:out
    execute "silent verbose " . a:command
  redir END

  return l:out
endfunction

" prepares the raw bundle data to be transformed into vim menus
function! s:InitBundleData()
  " all categories are disabled by default
  let s:commands = ''
  let s:mappings = ''
  let s:functions = ''
  let s:abbreviations = ''
  let s:autocmds = ''

  let s:scriptnames = s:GetCommandOutput('scriptnames')

  if (g:headlights_commands)
    let s:commands = s:GetCommandOutput('command')
  endif

  if (g:headlights_mappings)
    let s:mappings = s:GetCommandOutput('map')
  endif

  if (g:headlights_functions)
    let s:functions = s:GetCommandOutput('function')
  endif

  if (g:headlights_abbreviations)
    let s:abbreviations = s:GetCommandOutput('abbreviate')
  endif

  if (has('autocmd') && g:headlights_autocmds)
    let s:autocmds = s:GetCommandOutput('autocmd')
  endif
endfunction

" enables a top separator if the menu root previously exists
function! s:GetTopSeparator()
  try
    call s:GetCommandOutput('amenu ' . g:headlights_root)
  catch /E329/
    " menu doesn't exist
    return 0
  endtry
  return 1
endfunction

" attaches the bundle menus to GVim/MacVim
" (python spaghetti kept minimal)
function! s:AttachMenus()
  python import vim, time, traceback

  " time the execution of the vim code
  python vim.command("let l:vim_timer = %f" % time.time())

  " prepare the raw bundle data
  call s:InitBundleData()

  " load helper python script
  let l:scriptdir = matchlist(s:scriptnames, '\d\+:\s\+\([^ ]\+\)headlights.vim')[1]
  execute "pyfile " . l:scriptdir . "headlights.py"

  python << endpython

# initialise an instance of the helper script
headlights = Headlights(
    root=vim.eval("g:headlights_root"),
    spillover=vim.eval("g:headlights_spillover"),
    threshhold=vim.eval("g:headlights_threshhold"),
    topseparator=vim.eval("s:GetTopSeparator()"),
    debug=vim.eval("g:headlights_debug"),
    vim_timer=vim.eval("l:vim_timer"))

try:
    # get the menu commands from the helper script
    menu_commands = headlights.get_menu_commands(
        scriptnames=vim.eval("s:scriptnames"),
        commands=vim.eval("s:commands"),
        mappings=vim.eval("s:mappings"),
        abbreviations=vim.eval("s:abbreviations"),
        functions=vim.eval("s:functions"),
        autocmds=vim.eval("s:autocmds"))

    # run the menu commands to attach the script menus
    [vim.command(menu_cmd) for menu_cmd in menu_commands]

except:
    vim.command("echoerr('Headlights Exception: %s')" % traceback.format_exc())

endpython

endfunction
