-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)
--
-- Generated from .neomeowrc by scripts/gen_default_rc.lua — edit the rc, not this.

return [[
" ============================================================================
" .neomeowrc — THE default keymap of the neomeow.nvim plugin
" ----------------------------------------------------------------------------
" The plugin binds no keys in code: this file defines every default — the
" NORMAL/MOTION layout and the whole SPC keypad table — and ships bundled
" inside the plugin. Your own layer lives in a Lua settings file
" (stdpath('config')/neomeow.lua, i.e. ~/.config/nvim/neomeow.lua) returning
" { rc = { 'rc lines...' } } — each line uses the same syntax as this file
" and overrides the bundled default entry by entry; a deleted line falls
" back to the bundled default (bind `ignore` to disable a key).
" Open it with SPC c m — the first press creates neomeow.lua as a full
" copy of this file wrapped in the Lua table; reload after editing with
" SPC c M (":NeomeowReloadRc").
" Within this file, a later line for the same key wins.
"
" Syntax (see the README for the full guide):
"   nmap <key> <action>(excommand)    NORMAL-mode key -> Neovim ex command
"   nmap <key> <meow-command>         NORMAL-mode key -> named meow command
"   nmap <key> <meow keys>            NORMAL-mode key -> replayed meow keys
"   nnoremap ...                      like nmap, but the RHS resolves through
"                                     these bundled defaults, skipping user maps
"   mmap / mnoremap <key> <target>    the same, for MOTION mode (read-only
"                                     editors stay NORMAL)
"   map <leader><seq> <target>        keypad (SPC) entry
"   desc <leader><seq> <text>         which-key label for an entry or a group
"   set timeoutlen=300                which-key popup delay in ms
"   set nowhich-key                   turn the which-key popup off
" ============================================================================

set which-key
set timeoutlen=300

" ============================================================================
" The meow layout — QWERTY by default, every key rebindable
" ----------------------------------------------------------------------------
" Rebind any key to another meow command, to an <action>(...), or to
" replayed keys; bind a key to `ignore` to disable it.
" SPC is the keypad key and cannot be remapped; ESC and modifier
" chords never reach the modal engine (those live on Neovim keymaps).
" ============================================================================

" expand / counts
nmap 0 meow-expand-0
nmap 1 meow-expand-1
nmap 2 meow-expand-2
nmap 3 meow-expand-3
nmap 4 meow-expand-4
nmap 5 meow-expand-5
nmap 6 meow-expand-6
nmap 7 meow-expand-7
nmap 8 meow-expand-8
nmap 9 meow-expand-9
nmap - meow-negative-argument

" selections / things
nmap ; meow-reverse
nmap , meow-inner-of-thing
nmap . meow-bounds-of-thing
nmap [ meow-beginning-of-thing
nmap ] meow-end-of-thing
nmap < meow-beginning-of-thing
nmap > meow-end-of-thing

" the letter keys
nmap a meow-append
nmap A meow-open-below
nmap b meow-back-word
nmap B meow-back-symbol
nmap c meow-change
nmap d meow-delete
nmap D meow-backward-delete
nmap e meow-next-word
nmap E meow-next-symbol
nmap f meow-find
nmap g meow-cancel-selection
nmap G meow-grab
nmap h meow-left
nmap H meow-left-expand
nmap i meow-insert
nmap I meow-open-above
nmap j meow-next
nmap J meow-next-expand
nmap k meow-prev
nmap K meow-prev-expand
nmap l meow-right
nmap L meow-right-expand
nmap m meow-join
nmap n meow-search
nmap o meow-block
nmap O meow-to-block
nmap p meow-yank
nmap q meow-quit
nmap r meow-replace
nmap R meow-swap-grab
nmap s meow-kill
nmap t meow-till
nmap u meow-undo
nmap U meow-undo-in-selection
nmap v meow-visit
nmap w meow-mark-word
nmap W meow-mark-symbol
nmap x meow-line
nmap X meow-goto-line
nmap y meow-save
nmap Y meow-sync-grab
nmap z meow-pop-selection
nmap ' repeat

" MOTION mode — the keymap of list-like special buffers: j/k/h/l move like
" the arrow keys (h collapses or goes to the parent, l expands or enters),
" q hides the window, and every unmapped key keeps its native meaning.
" Read-only editors do NOT use MOTION; they stay NORMAL with the modify
" commands inert. `mmap <key> ignore` gives a key back to the surface.
mmap j meow-next
mmap k meow-prev
mmap h meow-left
mmap l meow-right
mmap q <action>(close)

" ============================================================================
" The keypad (SPC) table — every entry an rc line, like the layout above
" ----------------------------------------------------------------------------
" Group names follow the Emacs prefixes: SPC x / c / m = the C-x / C-c / M-
" keymaps. SPC 0-9 (digit argument), SPC ? (cheatsheet) and SPC / (describe
" key) are reserved by the keypad itself and cannot be remapped.
" <action>(...) bodies are Neovim ex command lines, run with :  — find names
" with SPC i d (the :command list) or :help.
" ============================================================================

" SPC b: buffers
map <leader>bb <action>(browse oldfiles)
map <leader><Space> <action>(b #)

" SPC x = C-x: files / buffers / windows
map <leader>xf <action>(Explore)
" SPC x z = C-x z: repeat the last command (then bare z keeps repeating)
map <leader>xz repeat
map <leader>xs <action>(wall)
map <leader>xb <action>(browse oldfiles)
map <leader>xk <action>(bdelete)
map <leader>xe <action>(normal! @@)
map <leader>xq <action>(set readonly!)
map <leader>xo ace-window
map <leader>xu <action>(undolist)
map <leader>xc <action>(confirm qall)
map <leader>x0 <action>(close)
map <leader>x1 <action>(only)
map <leader>x2 <action>(split)
map <leader>x3 <action>(vsplit)

" SPC x p = C-x p: project
map <leader>xpc <action>(make)

" SPC c = C-c: personal commands
map <leader>cf <action>(Explore)
map <leader>cs <action>(wall)
map <leader>ck <action>(bdelete)
map <leader>cc <action>(enew)
map <leader>cl <action>(let @+=expand('%').':'.line('.'))

" SPC c m / M: edit / reload the neomeow.lua settings file
map <leader>cm <action>(NeomeowEditRc)
map <leader>cM <action>(NeomeowReloadRc)

" SPC c j: avy jumps
map <leader>cjw avy-goto-char-timer
map <leader>cjc avy-goto-char-timer
map <leader>cjl avy-goto-line

" SPC m = M-: meta
" M- motions / edits — the meta layer under SPC m, the way meow's keypad
" exposes the whole M- map (SPC m f = M-f = forward-word, SPC m d = M-d, ...).
map <leader>ma backward-sentence
map <leader>mb backward-word
map <leader>mc capitalize-word
map <leader>md kill-word
map <leader>me forward-sentence
map <leader>mf forward-word
map <leader>ml downcase-word
map <leader>mu upcase-word
map <leader>m< beginning-of-buffer
map <leader>m> end-of-buffer
map <leader>m{ backward-paragraph
map <leader>m} forward-paragraph
map <leader>mx <action>(call feedkeys(':'))
map <leader>mo avy-goto-char-timer
map <leader>mq <action>(normal! gqip)
map <leader>m. <action>(lua vim.lsp.buf.definition())
map <leader>m, <action>(execute "normal! \<C-o>")
map <leader>mg avy-goto-line
map <leader>msl <action>(call feedkeys('/'))
map <leader>mss <action>(call feedkeys('/'))
map <leader>mso <action>(lua vim.lsp.buf.document_symbol())

" SPC w: the window map (Emacs C-c w)
map <leader>wv <action>(vsplit)
map <leader>ws <action>(split)
map <leader>wd <action>(close)
map <leader>wD <action>(only)
map <leader>wm <action>(only)
map <leader>ww ace-window
map <leader>wW ace-swap-window
map <leader>wr ace-resize
" n/p (aliases . and ,): cycle buffers (C-x <right>/<left>); the tab
" repeat group below keeps a bare n/p/./, walking afterwards
map <leader>wn <action>(bnext)
map <leader>wp <action>(bprevious)
map <leader>w. <action>(bnext)
map <leader>w, <action>(bprevious)
" h/j/k/l: directional window focus from the caret — real window geometry,
" splits AND diff panes. Plain Shift+arrows are bound to the same moves on
" Neovim keymaps by the adapter — modifier chords never reach the modal
" engine.
map <leader>wh <action>(NeomeowWindmoveLeft)
map <leader>wj <action>(NeomeowWindmoveDown)
map <leader>wk <action>(NeomeowWindmoveUp)
map <leader>wl <action>(NeomeowWindmoveRight)
" H/J/K/L: swap — the capitals mirror the h/j/k/l moves: your buffer and
" the focus travel to the neighbouring split, its buffer comes back
map <leader>wH <action>(NeomeowWindmoveSwapLeft)
map <leader>wJ <action>(NeomeowWindmoveSwapDown)
map <leader>wK <action>(NeomeowWindmoveSwapUp)
map <leader>wL <action>(NeomeowWindmoveSwapRight)
map <leader>wi <action>(resize +2)
map <leader>w= <action>(resize +2)
map <leader>wo <action>(resize -2)
map <leader>w- <action>(resize -2)
map <leader>wu <action>(wincmd =)
map <leader>w0 <action>(wincmd =)

" --- avy jumps ---------------------------------------------------------------
" S = avy-goto-char-timer, Q = avy-goto-line.
" Type chars (0.25 s pause labels the matches), then hit a label key;
" Q labels visible lines, digits switch to a line-number prompt.
nmap S avy-goto-char-timer
nmap Q avy-goto-line

" --- split resizing (= _ +) --------------------------------------------------
nmap = <action>(resize +2)
nmap _ <action>(vertical resize -4)
nmap + <action>(vertical resize +4)

" --- which-key labels for the keypad groups above ----------------------------
desc <leader>b buffers
desc <leader>x C-x · file / buffer / window
desc <leader>xp C-x p · project
desc <leader>c C-c · commands (= M-m)
desc <leader>cj C-c j · avy jump
desc <leader>m M- · meta
desc <leader>ms M-s · search
desc <leader>w window map (Emacs C-c w)

" ============================================================================
" Neovim feature groups on the SPC leader
" (b / c / m / w / x live in the keypad table above; digits and ? / are
" reserved by the keypad)
" ============================================================================

" --- SPC ; — settings / UI ---------------------------------------------------
desc <leader>; settings / UI
map <leader>;h <action>(nohlsearch)
map <leader>;l <action>(set number!)
map <leader>;s <action>(edit $MYVIMRC)
map <leader>;w <action>(set wrap!)

" --- SPC a — activate views --------------------------------------------------
desc <leader>a activate view
map <leader>af <action>(copen)
map <leader>an <action>(messages)
map <leader>ap <action>(Explore)
map <leader>aP <action>(lua vim.diagnostic.setqflist())
map <leader>at <action>(terminal)

" --- SPC e — expand folds ----------------------------------------------------
desc <leader>e folds
map <leader>ea <action>(normal! zR)

" --- SPC f — find / format ----------------------------------------------------
desc <leader>f find / format
map <leader>fi <action>(call feedkeys('/'))
map <leader>fm <action>(lua vim.lsp.buf.format())
map <leader>fn <action>(enew)
map <leader>fo <action>(lua vim.lsp.buf.format())
map <leader>fr <action>(browse oldfiles)
map <leader>fu <action>(lua vim.lsp.buf.references())

" --- SPC g — goto ---------------------------------------------------------------
desc <leader>g goto
map <leader>gd <action>(lua vim.lsp.buf.definition())
map <leader>gi <action>(lua vim.lsp.buf.implementation())

" --- SPC h — hide the extra views ----------------------------------------------
desc <leader>h hide the extra views
map <leader>h <action>(cclose | lclose | pclose | helpclose)

" --- SPC i — ids -----------------------------------------------------------------
desc <leader>i ids
" SPC i d: list every ex command usable inside <action>(...)
map <leader>id <action>(command)
desc <leader>id list command ids

" --- SPC j — quick docs / implementations -----------------------------------------
desc <leader>j docs / implementations
map <leader>jd <action>(lua vim.lsp.buf.hover())
map <leader>ji <action>(lua vim.lsp.buf.implementation())

" --- SPC l — history ----------------------------------------------------------------
desc <leader>l history
map <leader>lh <action>(undolist)

" --- SPC n — new (file / terminal / ...) ----------------------------------------------
desc <leader>n new
map <leader>ne <action>(enew)
map <leader>nf <action>(enew)
map <leader>ns <action>(enew)
map <leader>nt <action>(terminal)

" --- SPC o — open ------------------------------------------------------------------------
desc <leader>o open
map <leader>oe <action>(Explore)
map <leader>of <action>(Explore)
map <leader>oi <action>(lua vim.lsp.buf.code_action({context={only={'source.organizeImports'}},apply=true}))
map <leader>op <action>(Explore)
map <leader>ot <action>(terminal)

" --- SPC p — popup / docs -------------------------------------------------------------------
desc <leader>p popup / docs
map <leader>pd <action>(lua vim.lsp.buf.hover())
map <leader>ph <action>(lua vim.lsp.buf.hover())
map <leader>pi <action>(lua vim.lsp.buf.implementation())
map <leader>pp <action>(lua vim.lsp.buf.signature_help())

" --- SPC q — close the window ---------------------------------------------------------------
desc <leader>q close window
map <leader>q <action>(close)

" --- SPC r — run / refactor / replace -------------------------------------------------------
desc <leader>r run / refactor / replace
map <leader>re <action>(lua vim.lsp.buf.code_action())
map <leader>rf <action>(browse oldfiles)
map <leader>rl <action>(jumps)
map <leader>rn <action>(lua vim.lsp.buf.rename())
map <leader>rp <action>(call feedkeys(':%s/'))
map <leader>rr <action>(make)

" --- SPC s — search / show -------------------------------------------------------------------
desc <leader>s search / show
map <leader>sa <action>(call feedkeys(':'))
map <leader>sd <action>(lua vim.lsp.buf.hover())
map <leader>se <action>(lua vim.diagnostic.open_float())
map <leader>sh <action>(lua vim.lsp.buf.hover())
map <leader>sI <action>(lua vim.lsp.buf.code_action())
map <leader>ss <action>(call feedkeys('/'))
map <leader>sS <action>(lua vim.lsp.buf.workspace_symbol())
map <leader>su <action>(lua vim.lsp.buf.references())
" SPC s v: reload the neomeow.lua settings file
map <leader>sv <action>(NeomeowReloadRc)

" --- SPC . / SPC , — next / previous (diff / diagnostic / tab) --------------------------------
desc <leader>. next (diff / diagnostic / tab)
map <leader>.d <action>(normal! ]c)
map <leader>.e <action>(lua vim.diagnostic.jump({count=1}))
map <leader>.t <action>(bnext)
desc <leader>, previous (diff / diagnostic / tab)
map <leader>,d <action>(normal! [c)
map <leader>,e <action>(lua vim.diagnostic.jump({count=-1}))
map <leader>,t <action>(bprevious)

" ============================================================================
" Repeat groups — tap-to-continue transient maps
" ----------------------------------------------------------------------------
" After any binding whose TARGET is listed in a group below (membership is
" the target, not the key), the next keypress is first looked up in that
" group: a member key re-dispatches its target and keeps the run alive; any
" other key (or ESC) ends the run and keeps its normal meaning — nothing is
" swallowed, and there is no timeout. The entering keypad key needn't be a
" member. So: SPC . e then . . , walks diagnostics; SPC w i then i i i
" keeps resizing. Syntax:
"   repeat <group> <key> <target>     target grammar = the map-line RHS
"   repeat <group> <key> ignore       give a bundled group's key back
" ============================================================================
repeat error . <action>(lua vim.diagnostic.jump({count=1}))
repeat error , <action>(lua vim.diagnostic.jump({count=-1}))
repeat zoom i <action>(resize +2)
repeat zoom = <action>(resize +2)
repeat zoom o <action>(resize -2)
repeat zoom - <action>(resize -2)
repeat zoom u <action>(wincmd =)
repeat zoom 0 <action>(wincmd =)
repeat tab n <action>(bnext)
repeat tab p <action>(bprevious)
repeat tab . <action>(bnext)
repeat tab , <action>(bprevious)

" Emacs C-x z: after repeat (SPC x z or '), bare z keeps repeating
repeat replay z repeat
]]
