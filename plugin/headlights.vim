if has("gui_running")
  " NOTE: You may override the below default settings in your vimrc

  " The menu root. If you don't want an extra menu, set this to the default
  " "Plugin" menu or a submenu thereof (eg. "Plugin.Headlights").
  let g:headlights_root = "Bundles"

  " Categorise menu items alphabetically (1 to enable, 0 to disable)
  let g:headlights_spillover = 1

  " The threshhold after which the menu is categorised
  let g:headlights_threshhold = 30

  " A separator that precedes the menu (for eg. when reusing the "Plugin" menu)
  let g:headlights_topseparator = 0

  " add a menu placeholder
  execute "amenu " . g:headlights_root . ".Reveal :"

  command! Shine call <SID>MakeMenu()

endif

function! l:GetCommandOutput(command)
  redir => l:out
  execute "silent verbose " . a:command
  redir END
  return l:out
endfunction

function! s:MakeMenu()
  let l:scriptnames = l:GetCommandOutput("scriptnames")
  let l:commands = l:GetCommandOutput("command")
  let l:mappings = l:GetCommandOutput("map")
  let l:abbreviations = l:GetCommandOutput("abbreviate")
  let l:functions = l:GetCommandOutput("function")
  let l:autocmds = ""

  if has("autocmd")
    let l:autocmds = l:GetCommandOutput("autocmd")
  endif

  let l:scriptdir = matchlist(l:scriptnames, '\d\+:\s\+\([^ ]\+\)headlights.vim')[1]
  execute "pyfile " . l:scriptdir . "headlights.py"

  " remove menu placeholder
  execute "aunmenu " . g:headlights_root . ".Reveal"

  if (g:headlights_topseparator == 1)
    execute "amenu " . g:headlights_root . ".-Sep1- :"
  endif

python << endpython

import vim, time

timer_start = time.time()

# TODO: test the error handling
try:
    menu_commands = get_menu_commands(vim.eval("g:headlights_root"), \
        vim.eval("g:headlights_spillover"), \
        vim.eval("g:headlights_threshhold"), \
        vim.eval("l:scriptnames"), \
        vim.eval("l:commands"), \
        vim.eval("l:mappings"), \
        vim.eval("l:autocmds"))

    [vim.command(cmd) for cmd in menu_commands]

    timer_elapsed = (time.time() - timer_start)
    timer_message = "Headlights python code executed in %.2f seconds." % timer_elapsed
    vim.command("echomsg('" + timer_message + "')")

except Exception, message:
    error_message = "Headlights exception: %s" % message
    vim.command("echoerr('" + error_message.replace("'", "\'") + "')")
    pass

endpython

endfunction
