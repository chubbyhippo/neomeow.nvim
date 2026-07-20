# neomeow.nvim

Native [meow](https://github.com/meow-edit/meow)-style modal editing for
Neovim. neomeow parks every buffer in a **NORMAL** state where you *select
first, then act* — mark a word, a line, a pair, a search match, then change,
kill, or save it. It is not a Vim emulation and not built on Vim's operator
grammar: it is meow's selection-driven model, keyboard-for-keyboard, running
on Neovim's own buffers and windows.

The whole keymap — the QWERTY layout and the `SPC` keypad — lives in a bundled
`.neomeowrc` and is fully rebindable from a small Lua settings file. The plugin
binds no keys in code.

## Requirements

- Neovim 0.10+ (developed and tested on 0.12)

## Install

With any plugin manager, or clone and run `./setup.sh` (it runs the test suite,
then symlinks the repo into your Neovim pack path). Then, in `init.lua`:

```lua
require('neomeow').setup()
```

lazy.nvim:

```lua
{ 'chubbyhippo/neomeow.nvim', config = function() require('neomeow').setup() end }
```

`setup()` accepts options:

```lua
require('neomeow').setup({
  -- restrict meow to these filetypes (default: every normal buffer)
  filetypes = { 'lua', 'python', 'markdown' },
  -- inline overrides instead of the neomeow.lua settings file
  rc = { 'nmap S avy-goto-char-timer' },
})
```

## The model in one screen

Press `SPC ?` any time for the built-in cheatsheet.

```
NORMAL — selection first, then act
  h j k l  move (cancel selection)       H J K L  extend char selection
  w / W    mark word / symbol            e / E    next word / symbol end
  b / B    back word / symbol            x        line (repeat: extend)
  f / t    find / till char              o / O    block / to end of block
  , / .    inner / bounds of thing       [ / ]    to beginning / end of thing
     things: r ( )  s [ ]  c { }  g string  e symbol  w window  b buffer
             p paragraph  l line  v visual line  d defun  . sentence
  1-9, 0   expand selection by N (0 = 10); with no selection: a count
  ;        reverse selection             -        negative argument
  i / a    insert / append               I / A    open line above / below
  c        change      s   kill (cut)    d / D    delete char fwd / back
  y        save (copy) p   yank (paste)  r        replace with clipboard
  u        undo        '   repeat last   n        search next
  v        visit (regexp)                z        pop selection (or grab)
  g        cancel selection / cursors    G        grab   R / Y  swap / sync grab
  Q / X    goto line   S   jump (avy)    q        close window
```

`SPC` opens the keypad (Emacs-style prefixes): `SPC x` files/windows, `SPC c`
commands, `SPC w` windows, `SPC m` meta, `SPC g` goto, `SPC s` search, and so
on. `SPC c m` opens your settings file; `SPC c M` reloads it. A which-key popup
lists the continuations after a short delay (`set nowhich-key` to disable).

Selections render as a highlight; the block/bar cursor follows the mode
natively. Grab a region with `G`, then select inside it (`w`, `x`, a search…)
to drop a cursor on every match and edit them together — press `ESC` to finish.

## Settings — `neomeow.lua`

Your personal layer is a Lua file at `stdpath('config')/neomeow.lua` that
returns `{ rc = { <lines> } }`. Each string is one rc line and overrides the
bundled default entry by entry; everything you don't mention keeps its default.
`SPC c m` creates it (seeded with a template) and opens it; `SPC c M` reloads.

```lua
return {
  rc = {
    'nmap S avy-goto-char-timer',                  -- rebind a NORMAL key to a command
    'map <leader>ff <action>(Telescope find_files)', -- a keypad entry -> an ex command
    'desc <leader>f find',                         -- which-key label
    'set timeoutlen=200',
  },
}
```

rc line grammar:

| Line | Meaning |
|---|---|
| `nmap <key> <meow-command>` | NORMAL key → a named meow command |
| `nmap <key> <action>(excmd)` | NORMAL key → run `:excmd` |
| `nmap <key> <keys>` | NORMAL key → replay meow keys |
| `nnoremap …` | like `nmap`, but the RHS resolves through the bundled defaults |
| `mmap / mnoremap <key> <t>` | the same, for MOTION-state (list-like) buffers |
| `map <leader><seq> <target>` | keypad (`SPC`) entry |
| `desc <leader><seq> <text>` | which-key label for an entry or group |
| `set timeoutlen=N` · `set nowhich-key` | which-key popup delay / off |
| `repeat <group> <key> <target>` | tap-to-continue run (see below) |

Bind a key to `ignore` to disable it. `<action>(…)` runs its body as a Neovim
ex-command line (`<action>(vsplit)`, `<action>(lua vim.lsp.buf.hover())`,
`<action>(Telescope find_files)`); list command names with `SPC i d`.

### Repeat runs

Some keypad entries start a tap-to-continue run (Emacs `repeat-mode`): after
`SPC . e` keep tapping `.` / `,` to walk diagnostics; after `SPC w i` keep
tapping `i` to keep resizing. Any other key ends the run and keeps its normal
meaning. Define your own with `repeat <group> <key> <target>`.

## Read-only and special buffers

Read-only buffers stay in NORMAL — motions, selections, search, and avy all
work; the modifying commands quietly no-op or report "Buffer is read-only".
Terminal, prompt, and quickfix buffers are left to Neovim.

## Development

```bash
nvim -l tests/run.lua                       # the BDD suite
nvim --headless -u NONE -i NONE -l tests/smoke.lua   # adapter wiring
```

The behavior lives in `lua/neomeow/core/` behind a small host-port seam and is
covered by a full BDD suite that runs headlessly in milliseconds; the Neovim
wiring is the thin adapter in `lua/neomeow/`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
