" Headlights - One 'Bundles' menu to rule them all.
" Version: 1.2
" Home: <www.vim.org/scripts/script.php?script_id=3455>
" Source:	<github.com/mbadran/headlights>
" Maintainer:	Mohammed Badran <mebadran _AT_ gmail>

" boilerplate {{{1

if exists('g:loaded_headlights') || &cp
  finish
endif

if v:version < 700 || !has('python')
  echoerr 'Headlights requires Vim 7+ compiled with Python 2.6+ support.'
  finish
endif

let g:loaded_headlights = 1

" configuration {{{1

" only commands and mappings are enabled by default
let s:use_plugin_menu = exists('g:headlights_use_plugin_menu')? g:headlights_use_plugin_menu : 0
let s:show_files = exists('g:headlights_show_files')? g:headlights_show_files : 0
let s:show_commands = exists('g:headlights_show_commands')? g:headlights_show_commands : 1
let s:show_mappings = exists('g:headlights_show_mappings')? g:headlights_show_mappings : 1
let s:show_abbreviations = exists('g:headlights_show_abbreviations')? g:headlights_show_abbreviations : 0
let s:show_functions = exists('g:headlights_show_functions')? g:headlights_show_functions : 0
let s:debug_mode = exists('g:headlights_debug_mode')? g:headlights_debug_mode : 0

let s:menu_root = s:use_plugin_menu? 'Plugin.headlights' : 'Bundles'

let s:scriptdir = expand("<sfile>:h") . '/'

" action {{{1

autocmd GUIEnter,BufEnter,FileType * call s:RequestVimMenus()

" imports are done here for performance reasons
python import vim, time, sys, os, re

function! s:GetVimCommandOutput(command) " {{{1
  " initialise to a blank value in case the command throws a vim error
  " (try-catch doesn't work properly here, for some reason)
  let l:output = ''

  redir => l:output
    execute "silent verbose " . a:command
  redir END

  return l:output
endfunction

" prepares the raw bundle data to be transformed into vim menus
function! s:InitBundleData() " {{{1
  let s:scriptnames = s:GetVimCommandOutput('scriptnames')
  let s:commands = s:show_commands? s:GetVimCommandOutput('command') : ''
	let s:mappings = s:show_mappings? s:GetVimCommandOutput('map') : ''
	let s:abbreviations = s:show_abbreviations? s:GetVimCommandOutput('abbreviate') : ''
	let s:functions = s:show_functions? s:GetVimCommandOutput('function') : ''
endfunction

" requests the bundle menus from the helper python script
" (minimise python spaghetti)
function! s:RequestVimMenus() " {{{1
	" time the execution of the vim code
	python time_start = time.time()

	" prepare the raw bundle data
	call s:InitBundleData()

	" load helper python script
  execute 'pyfile ' . s:scriptdir . 'headlights.py'

	" initialise an instance of the helper script
	python headlights = Headlights(
			\ menu_root=vim.eval("s:menu_root"),
			\ debug_mode=vim.eval("s:debug_mode"),
			\ vim_time=time.time() - time_start,
			\ enable_files=vim.eval("s:show_files"),
			\ scriptnames=vim.eval("s:scriptnames"),
			\ commands=vim.eval("s:commands"),
			\ mappings=vim.eval("s:mappings"),
			\ abbreviations=vim.eval("s:abbreviations"),
			\ functions=vim.eval("s:functions"))
endfunction
