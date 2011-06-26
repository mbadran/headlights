" Headlights is a Vim plugin that provides a TextMate-like 'Bundles' menu.
"
" Version: 1.2
" Maintainer:	Mohammed Badran <mebadran AT gmail>

if &cp || exists('g:loaded_headlights')
  finish
endif
if v:version < 700 || !has('python')
  echoerr 'Headlights requires Vim 7+ with Python support.'
  finish
endif
let g:loaded_headlights = 1

" settings {{{1
" Enable this to reuse the Plugin menu.
if !exists('g:headlights_use_plugin_menu')
  let g:headlights_use_plugin_menu = 0
endif

" Individual menu components. Enable or disable to preference.
if !exists('g:headlights_files')
  let g:headlights_files = 0
endif

if !exists('g:headlights_commands')
	let g:headlights_commands = 1
endif

if !exists('g:headlights_mappings')
  let g:headlights_mappings = 0
endif

if !exists('g:headlights_abbreviations')
  let g:headlights_abbreviations = 0
endif

if !exists('g:headlights_functions')
  let g:headlights_functions = 0
endif

" Debug mode. Enable to debug any errors or performance issues.
" IMPORTANT: Set this to 0 when you're done, otherwise log files will be
" generated every time you enter a buffer.
if !exists('g:headlights_debug_mode')
  let g:headlights_debug_mode = 0
endif

" functions {{{1
function! s:GetVimCommandOutput(command) " {{{2
  " initialise to a blank value in case the command throws a vim error
  " (try-catch doesn't work properly here, for some reason)
  let l:output = ''

  redir => l:output
    execute "silent verbose " . a:command
  redir END

  return l:output
endfunction

" prepares the raw bundle data to be transformed into vim menus
function! s:InitBundleData() " {{{2
  let s:scriptnames = s:GetVimCommandOutput('scriptnames')

  " all categories are disabled by default
	let s:commands = g:headlights_commands? s:GetVimCommandOutput('command') : ''
	let s:mappings = g:headlights_mappings? s:GetVimCommandOutput('map') : ''
	let s:abbreviations = g:headlights_abbreviations? s:GetVimCommandOutput('abbreviate') : ''
	let s:functions = g:headlights_functions? s:GetVimCommandOutput('function') : ''
endfunction

" requests the bundle menus from the helper python script
" (minimise python spaghetti)
function! s:RequestVimMenus() " {{{2
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
      \ enable_files=vim.eval("g:headlights_files"),
      \ scriptnames=vim.eval("s:scriptnames"),
      \ commands=vim.eval("s:commands"),
      \ mappings=vim.eval("s:mappings"),
      \ abbreviations=vim.eval("s:abbreviations"),
      \ functions=vim.eval("s:functions"))
endfunction

" action {{{1
if g:headlights_use_plugin_menu
  let s:menu_root = 'Plugin'
  amenu Plugin.-SepHLM- :
else
  let s:menu_root = 'Bundles'
endif

autocmd GUIEnter,BufEnter,FileType * call s:RequestVimMenus()

python import vim, time
