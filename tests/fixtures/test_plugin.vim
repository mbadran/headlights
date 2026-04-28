" Minimal fake plugin used by headlights integration tests.
" Source this file programmatically — do not install it as a real plugin.
"
" It deliberately uses the prefix HeadlightsFixture so nothing conflicts with
" real plugin resources during testing.

command!          HeadlightsFixtureCmd   echo 'headlights_fixture_command'
command! -nargs=? HeadlightsFixtureCmd2  echo 'headlights_fixture_command2 ' . <q-args>

nnoremap <silent> <leader>HLfx  :echo 'headlights_fixture_normal_map'<CR>
inoremap <silent> <C-HLfx>      <Esc>:echo 'headlights_fixture_insert_map'<CR>a

iabbrev  HLfxabrv                headlights_fixture_abbreviation_value

" Highlight + autocmd + sign exercise the wider attribution paths.
highlight HeadlightsFixtureHL    guifg=#abcabc

augroup HeadlightsFixtureGroup
  autocmd!
  autocmd BufRead *.headlights_fixture echo 'headlights_fixture_autocmd'
augroup END

call sign_define('HeadlightsFixtureSign', { 'text': '◉', 'texthl': 'HeadlightsFixtureHL' })
