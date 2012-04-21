" Headlights - Know thy Bundles.
" Version: 1.5.1
" Home: www.vim.org/scripts/script.php?script_id=3455
" Development: github.com/mbadran/headlights
" Maintainer: Mohammed Badran <mebadran _AT_ gmail>

" boilerplate {{{1

if exists("g:loaded_headlights") || &cp
  finish
endif

try
  python import vim, sys
  python if (sys.version_info[0:2]) < (2, 6): vim.command("let s:invalid_python = 1")
catch /E319/    " no python
  let s:invalid_python = 1
endtry

if v:version < 700 || exists("s:invalid_python")
  echomsg("Headlights requires Vim 7+ compiled with Python 2.6+ support.")
  finish
endif

let g:loaded_headlights = 1

let s:save_cpo = &cpo
set cpo&vim

" configuration {{{1

" only enable commands, mappings, and smart menus by default
let s:use_plugin_menu = exists("g:headlights_use_plugin_menu")? g:headlights_use_plugin_menu : 0
let s:show_files = exists("g:headlights_show_files")? g:headlights_show_files : 0
let s:show_commands = exists("g:headlights_show_commands")? g:headlights_show_commands : 1
let s:show_mappings = exists("g:headlights_show_mappings")? g:headlights_show_mappings : 1
let s:show_abbreviations = exists("g:headlights_show_abbreviations")? g:headlights_show_abbreviations : 0
let s:show_functions = exists("g:headlights_show_functions")? g:headlights_show_functions : 0
let s:show_highlights = exists("g:headlights_show_highlights")? g:headlights_show_highlights : 0
let s:show_load_order = exists("g:headlights_show_load_order")? g:headlights_show_load_order : 0
let s:smart_menus = exists("g:headlights_smart_menus")? g:headlights_smart_menus : 1
let s:debug_mode = exists("g:headlights_debug_mode")? g:headlights_debug_mode : 0

let s:menu_root = s:use_plugin_menu? "Plugin.headlights" : "Bundles"

let s:scriptdir = expand("<sfile>:h") . "/"

" pyargs {{{1

" do one-off python stuff here, for performance reasons

python << endpython

import time, os, re

# initialise global configuration vars

MENU_ROOT = vim.eval("s:menu_root")
SHOW_FILES = bool(int(vim.eval("s:show_files")))
SHOW_LOAD_ORDER = bool(int(vim.eval("s:show_load_order")))
SMART_MENUS = bool(int(vim.eval("s:smart_menus")))
DEBUG_MODE = bool(int(vim.eval("s:debug_mode")))

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

HIGHLIGHT_PATTERN = re.compile(r'''
    ^
    (?P<group>\w+)
    \\s+
    xxx
    \\s+
    (?P<arguments>.+)
    $
    ''', re.VERBOSE | re.IGNORECASE)

VIM_DIR_PATTERNS = [
    re.compile(r".+/after(/.*)?$", re.IGNORECASE),
    re.compile(r".+/autoload(/.*)?$", re.IGNORECASE),
    re.compile(r".+/colors$", re.IGNORECASE),
    re.compile(r".+/compiler$", re.IGNORECASE),
    #re.compile(r".+/doc$", re.IGNORECASE),
    re.compile(r".+/ftdetect$", re.IGNORECASE),
    re.compile(r".+/ftplugin(/.*)?$", re.IGNORECASE),
    re.compile(r".+/function$", re.IGNORECASE),         # not a standard vim dir
    re.compile(r".+/indent$", re.IGNORECASE),
    #re.compile(r".+/keymap$", re.IGNORECASE),
    #re.compile(r".+/lang$", re.IGNORECASE),
    re.compile(r".+/macros$", re.IGNORECASE),
    re.compile(r".+/plugin$", re.IGNORECASE),
    #re.compile(r".+/print$", re.IGNORECASE),
    #re.compile(r".+/spell$", re.IGNORECASE),
    re.compile(r".+/syntax$", re.IGNORECASE),
    re.compile(r".+/systags$", re.IGNORECASE),
    re.compile(r".+/view$", re.IGNORECASE)]
    #re.compile(r".+/tools$", re.IGNORECASE),
    #re.compile(r".+/tutor$", re.IGNORECASE)]

endpython

function! s:RequestVimMenus() " {{{1
  " requests the bundle menus from the helper python script

  if !exists("b:headlights_buffer_updated")
    " time the execution of the vim commands
    python start_time = time.time()

    call s:InitBundleData()

    execute 'pyfile ' . s:scriptdir . 'headlights.py'

python << endpython

try:
    run_headlights(vim_time = float(time.time() - start_time),
        vim_scriptnames = vim.eval("s:scriptnames"),
        commands = vim.eval("s:commands"),
        mappings = vim.eval("s:mappings"),
        abbreviations = vim.eval("s:abbreviations"),
        functions = vim.eval("s:functions"),
        highlights = vim.eval("s:highlights"))

except Exception:
    import traceback
    sys.stdout.write("Headlights encountered a critical error. %s" % traceback.format_exc())

endpython

    let b:headlights_buffer_updated = 1
  endif
endfunction

function! s:InitBundleData() " {{{1
  " prepares the raw bundle data to be transformed into vim menus

  let s:scriptnames = s:GetVimCommandOutput("scriptnames")
  let s:commands = s:show_commands? s:GetVimCommandOutput("command") : ""
  let s:mappings = s:show_mappings? s:GetVimCommandOutput('map') . s:GetVimCommandOutput('map!') : ""
  let s:abbreviations = s:show_abbreviations? s:GetVimCommandOutput("abbreviate") : ""
  let s:functions = s:show_functions? s:GetVimCommandOutput("function") : ""
  let s:highlights = s:show_highlights? s:GetVimCommandOutput("highlight") : ""
endfunction

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

function! s:ResetBufferState() " {{{1
  " remove the local buffer's menu and reset its state

  if exists("b:headlights_buffer_updated")
    unlet b:headlights_buffer_updated
  endif

  try
    execute "aunmenu " . s:menu_root . ".⁣⁣buffer"
  catch /E329/
  endtry
endfunction

" controller {{{1

augroup headlights
  autocmd!
  autocmd GUIEnter,CursorHold * call s:RequestVimMenus()
  " reset buffer menus when leaving, and when the filetype changes
  autocmd BufLeave * call s:ResetBufferState()
  autocmd FileType * if exists("b:headlights_buffer_updated")|call s:ResetBufferState()|endif
augroup END

" boilerplate {{{1

let &cpo = s:save_cpo
