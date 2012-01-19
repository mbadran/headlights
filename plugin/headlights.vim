" Headlights - Know Thy Bundles.
" Version: 1.3
" Home: <www.vim.org/scripts/script.php?script_id=3455>
" Development:	<github.com/mbadran/headlights>
" Maintainer:	Mohammed Badran <mebadran _AT_ gmail>

" boilerplate {{{1

if exists('g:loaded_headlights') || &cp
  finish
endif

if v:version < 700 || !has('python')
  echomsg 'Headlights requires Vim 7+ compiled with Python 2.6+ support.'
  " (it's too much trouble to check for the python version)
  finish
endif

let g:loaded_headlights = 1

let s:save_cpo = &cpo
set cpo&vim

" configuration {{{1

" only enable commands and mappings by default
let s:use_plugin_menu = exists('g:headlights_use_plugin_menu')? g:headlights_use_plugin_menu : 0
let s:show_files = exists('g:headlights_show_files')? g:headlights_show_files : 0
let s:show_commands = exists('g:headlights_show_commands')? g:headlights_show_commands : 1
let s:show_mappings = exists('g:headlights_show_mappings')? g:headlights_show_mappings : 1
let s:show_abbreviations = exists('g:headlights_show_abbreviations')? g:headlights_show_abbreviations : 0
let s:show_functions = exists('g:headlights_show_functions')? g:headlights_show_functions : 0
let s:show_load_order = exists('g:headlights_show_load_order')? g:headlights_show_load_order : 0
let s:debug_mode = exists('g:headlights_debug_mode')? g:headlights_debug_mode : 0

let s:menu_root = s:use_plugin_menu? 'Plugin.headlights' : 'Bundles'

let s:scriptdir = expand("<sfile>:h") . '/'

" pyargs {{{1

python << endpython

# do imports here, for performance reasons
import vim, time, sys, os, re

# initialise python globals as script args, for performance reasons

MODE_MAP = {
    " ": "Normal, Visual, Select, Operator-pending",
    "n": "Normal",
    "v": "Visual and Select",
    "s": "Select",
    "x": "Visual",
    "o": "Operator-pending",
    "!": "Insert and Command-line",
    "i": "Insert",
    "l": ":lmap",
    "c": "Command-line"
}

SOURCE_LINE = "Last set from"

MENU_TRUNC_LIMIT = 30

MENU_SPILLOVER_PATTERNS = {
    re.compile(r"\.?_?\d", re.IGNORECASE): "0 - 9",
    re.compile(r"\.?_?[a-i]", re.IGNORECASE): "a - i",
    re.compile(r"\.?_?[j-r]", re.IGNORECASE): "j - r",
    re.compile(r"\.?_?[s-z]", re.IGNORECASE): "s - z"
}

COMMAND_PATTERN = re.compile(r'''
    ^
    (?P<bang>!)?
    \\s*
    (?P<register>")?
    \\s*
    (?P<buffer>b\s+)?
    (?P<name>[\S]+)
    \\s+
    (?P<args>[01+?*])?
    \\s*
    (?P<range>(\.|1c|%|0c))?
    \\s*
    (?P<complete>(dir|file|buffer))?
    \\s*
    :?
    (?P<definition>.+)?
    $
    ''', re.VERBOSE | re.IGNORECASE)

MAPPING_PATTERN = re.compile(r'''
    ^
    (?P<modes>[nvsxo!ilc]+)?
    \\s*
    (?P<lhs>[\S]+)
    \\s+
    (?P<noremap>\*)?
    (?P<script>&)?
    (?P<buffer>@)?
    \\s*
    (?P<rhs>.+)
    $
    ''', re.VERBOSE | re.IGNORECASE)

ABBREV_PATTERN = re.compile(r'''
    ^
    (?P<modes>[nvsxo!ilc]+)?
    \\s*
    (?P<lhs>[\S]+)
    \\s+
    (?P<noremap>\*)?
    (?P<script>&)?
    (?P<buffer>@)?
    \\s*
    (?P<rhs>.+)
    $
    ''', re.VERBOSE | re.IGNORECASE)

SCRIPTNAME_PATTERN = re.compile(r'''
    ^
    \\s*
    (?P<order>\d+)
    :
    \\s
    (?P<path>.+)
    $
    ''', re.VERBOSE)

sys.argv = [vim.eval("s:menu_root"),
    bool(int(vim.eval("s:show_files"))),
    bool(int(vim.eval("s:show_load_order"))),
    bool(int(vim.eval("s:debug_mode"))),
    MODE_MAP,
    SOURCE_LINE,
    MENU_TRUNC_LIMIT,
    MENU_SPILLOVER_PATTERNS,
    COMMAND_PATTERN,
    MAPPING_PATTERN,
    ABBREV_PATTERN,
    SCRIPTNAME_PATTERN]

endpython

function! s:GetVimCommandOutput(command) " {{{1
  " capture and return the output of a vim command

  " initialise to a blank value in case the command throws a vim error
  " (try-catch doesn't always work here, for some reason)
  let l:output = ''

  redir => l:output
    execute "silent verbose " . a:command
  redir END

  return l:output
endfunction

function! s:InitBundleData() " {{{1
  " prepares the raw bundle data to be transformed into vim menus

  let s:scriptnames = s:GetVimCommandOutput('scriptnames')
  let s:commands = s:show_commands? s:GetVimCommandOutput('command') : ''
	let s:mappings = s:show_mappings? s:GetVimCommandOutput('map') . s:GetVimCommandOutput('map!') : ''
	let s:abbreviations = s:show_abbreviations? s:GetVimCommandOutput('abbreviate') : ''
	let s:functions = s:show_functions? s:GetVimCommandOutput('function') : ''
endfunction

function! s:RequestVimMenus() " {{{1
  " requests the bundle menus from the helper python script

  " time the excution of the vim commands
  python time_start = time.time()

	call s:InitBundleData()

  execute 'pyfile ' . s:scriptdir . 'headlights.py'

python << endpython

try:
    headlights = Headlights(vim_time = time.time() - time_start,
        scriptnames = vim.eval("s:scriptnames"),
        commands = vim.eval("s:commands"),
        mappings = vim.eval("s:mappings"),
        abbreviations = vim.eval("s:abbreviations"),
        functions = vim.eval("s:functions"))

except Exception:
    import traceback
    sys.stdout.write("Headlights encountered a critical error. %s" % traceback.format_exc())

endpython

endfunction

" controller {{{1

autocmd GUIEnter,BufEnter,FileType * call s:RequestVimMenus()

" boilerplate {{{1

let &cpo = s:save_cpo
