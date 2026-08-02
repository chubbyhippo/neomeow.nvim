# neomeow.nvim

Native [meow](https://github.com/meow-edit/meow)-style modal editing for
Neovim — every buffer parks in a **NORMAL** state where you select first, then
act.

| | |
|---|---|
| Model | meow's selection-driven model, keyboard-for-keyboard — not a Vim emulation, not built on Vim's operator grammar |
| Runs on | Neovim's own buffers and windows |
| Keymap | the QWERTY layout and the `SPC` keypad, in a bundled `.neomeowrc` |
| Rebinding | a small Lua settings file; the plugin binds no keys in code |
| Requires | Neovim 0.10+ (developed and tested on 0.12) |

## Install

Any plugin manager, or clone and run `./setup.sh` — it runs the checks, then
symlinks the repo into your Neovim pack path.

`init.lua`:

```lua
require('neomeow').setup()
```

lazy.nvim:

```lua
{ 'chubbyhippo/neomeow.nvim', config = function() require('neomeow').setup() end }
```

`setup()` options:

```lua
require('neomeow').setup({
  -- restrict meow to these filetypes (default: every normal buffer)
  filetypes = { 'lua', 'python', 'markdown' },
  -- inline overrides instead of the neomeow.lua settings file
  rc = { 'nmap S avy-goto-char-timer' },
})
```

## The model in one screen

`SPC ?` opens this as the built-in cheatsheet.

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

| Surface | Behavior |
|---|---|
| `SPC` keypad | Emacs-style prefixes — `SPC x` files/windows, `SPC c` commands, `SPC w` windows, `SPC m` meta, `SPC g` goto, `SPC s` search |
| `SPC c m` / `SPC c M` | open / reload your settings file |
| which-key | lists the continuations after a short delay; `set nowhich-key` disables it |
| Selections | a highlight; the block/bar cursor follows the mode natively |
| `G` then a selection inside it | drops a cursor on every match, edits them together; `ESC` finishes |

## Settings — `neomeow.lua`

| Item | Value |
|---|---|
| Path | `stdpath('config')/neomeow.lua` |
| Returns | `{ rc = { <lines> } }` — each string one rc line |
| Precedence | overrides the bundled default entry by entry; anything unmentioned keeps its default |
| `SPC c m` | creates it seeded with a template, and opens it |
| `SPC c M` | reloads it |

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

### rc line grammar

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
| `set overlay-color=#RRGGBB` … | overlay / hint / grab colors (see below) |
| `repeat <group> <key> <target>` | tap-to-continue run (see below) |
| `<key> ignore` | disable the key |

| `<action>(…)` | Runs its body as a Neovim ex-command line |
|---|---|
| `<action>(vsplit)` | a plain ex command |
| `<action>(lua vim.lsp.buf.hover())` | Lua |
| `<action>(Telescope find_files)` | a plugin command |
| `SPC i d` | lists the command names |

### Colors

One `#RRGGBB` per key, applied in both light and dark backgrounds.

| Line | Colors |
|---|---|
| `set overlay-color=#RRGGBB` | the avy / ace label background |
| `set overlay-text-color=#RRGGBB` | the avy / ace label text |
| `set expand-hint-color=#RRGGBB` | the `0`–`9` expand-hint badge |
| `set grab-color=#RRGGBB` | the grab / beacon highlight |

| Case | Result |
|---|---|
| Line left out | the built-in default — the grab highlight then follows your colorscheme's `DiffAdd` |
| Malformed hex | reported like any other rc error; the color stays at its default |

### Repeat runs

Emacs `repeat-mode`.

| Fact | Value |
|---|---|
| Inside a run | a member key keeps it alive |
| Any other key | ends the run and keeps its normal meaning |
| Define your own | `repeat <group> <key> <target>` |

| After | Keep tapping | To |
|---|---|---|
| `SPC . e` | `.` / `,` | walk diagnostics |
| `SPC w i` | `i` | keep resizing |

## Read-only and special buffers

| Buffer | Behavior |
|---|---|
| Read-only | stays in NORMAL — motions, selections, search and avy work; modifying commands no-op or report "Buffer is read-only" |
| Terminal, prompt, quickfix | left to Neovim |

## Development

```bash
./scripts/check.sh   # formatting, lint, the BDD suite, adapter wiring
```

That one command is the gate `./setup.sh` runs.

| Stage | Tool / scope |
|---|---|
| Format | `stylua --check` over `lua plugin tests scripts` |
| Lint | `selene` over the same, `shellcheck` over the shell scripts |
| Sync | the generated `default_rc` matches `.neomeowrc` |
| Behavior | the BDD suite and the adapter smoke test |

| Config file | Declares |
|---|---|
| `selene.toml` / `neovim.yml` | the Lua dialect and Neovim's `vim` global |
| `.stylua.toml` | the house format — 2-space indent, single quotes |
| `.luacheckrc` | the dialect and the same global; `luacheck` passes clean but ships no binary release, so the gate does not require it |
| `mise.toml` | pins Neovim, stylua, selene and shellcheck; the script fetches them through mise when they are not on PATH |

Every tool runs on its stock rules — no rule-config file, no baseline.

| Layer | Where |
|---|---|
| Behavior | `lua/neomeow/core/`, behind a small host-port seam, covered by a headless BDD suite |
| Neovim wiring | the thin adapter in `lua/neomeow/` |

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
