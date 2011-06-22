" Headlights is a Vim plugin that provides a TextMate-like 'Bundles' menu.
" Version: 1.2
" Maintainer:	Mohammed Badran <mebadran AT gmail>

" TODO: fix the open file feature (busted with headlights, for eg.)

if &cp || exists('g:loaded_headlights') || !has('gui_running')
  finish
endif
let g:loaded_headlights = 1

" settings {{{
" Enable this to reuse the Plugin menu.
if !exists('g:headlights_use_plugin_menu')
  let g:headlights_use_plugin_menu = 0
endif

" Individual menu components. Enable or disable to preference.
if !exists('g:headlights_commands')
  let g:headlights_commands = 1
endif

if !exists('g:headlights_mappings')
  let g:headlights_mappings = 1
endif

if !exists('g:headlights_abbreviations')
  let g:headlights_abbreviations = 1
endif

" Debug mode. Enable to debug any errors or performance issues.
" IMPORTANT: Set this to 0 when you're done, otherwise log files will be
" generated every time you enter a buffer.
if !exists('g:headlights_debug_mode')
  let g:headlights_debug_mode = 0
endif
" }}}

" functions {{{
" returns the output of a vim command
function! s:GetCommandOutput(command)
  " initialise to a blank value in case the command throws a vim error
  " (try-catch doesn't work properly here, for some reason)
  let l:output = ''

  redir => l:output
    execute "silent verbose " . a:command
  redir END

  return l:output
endfunction

" prepares the raw bundle data to be transformed into vim menus
function! s:InitBundleData()
  " all categories are disabled by default
  let s:commands = ''
  let s:mappings = ''
  let s:abbreviations = ''

  let s:scriptnames = s:GetCommandOutput('scriptnames')

  if g:headlights_commands
    let s:commands = s:GetCommandOutput('command')
  endif

  if g:headlights_mappings
    let s:mappings = s:GetCommandOutput('map')
  endif

  if g:headlights_abbreviations
    let s:abbreviations = s:GetCommandOutput('abbreviate')
  endif
endfunction

" requests the bundle menus from the helper python script
" (minimise python spaghetti)
function! s:RequestMenus()
  " time the execution of the vim code
  python time_start = time.time()

  " prepare the raw bundle data
  call s:InitBundleData()

  " load helper python script
  let l:scriptdir = matchlist(s:scriptnames, '\d\+:\s\+\([^ ]\+\)headlights.vim')[1]
  execute "pyfile " . l:scriptdir . "headlights.py"

  " initialise an instance of the helper script
  python headlights = Headlights(
      \ menu_root=vim.eval("s:menu_root"),
      \ debug_mode=vim.eval("g:headlights_debug_mode"),
      \ vim_time=time.time() - time_start,
      \ scriptnames=vim.eval("s:scriptnames"),
      \ commands=vim.eval("s:commands"),
      \ mappings=vim.eval("s:mappings"),
      \ abbreviations=vim.eval("s:abbreviations"))

  if s:menu_root == 'Bundles'
    try | aunmenu Bundles.placeholder | catch /E329/ | endtry
  endif
endfunction
" }}}

" action {{{
if g:headlights_use_plugin_menu
  let s:menu_root = 'Plugin'
  amenu Plugin.-Sep- :
else
  let s:menu_root = 'Bundles'
  amenu Bundles.placeholder :
endif

autocmd BufEnter * call s:RequestMenus()

python import vim, time
" }}}
