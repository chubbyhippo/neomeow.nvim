-- Copyright (C) 2026 Chubby Hippo
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: GPL-3.0-or-later

local port_ = require('neomeow.core.port')
local Rc = require('neomeow.core.rc')

local M = {}

M.CHEATSHEET = ([[
The bundled default layout (meow's suggested QWERTY) — every key below can
be rebound from the neomeow.lua settings file (SPC c m opens it).

NORMAL — selection first, then act
  h j k l  move (cancel selection)       H J K L  extend char selection
  w / W    mark word / symbol            e / E    next word / symbol end
  b / B    back word / symbol            x        line (repeat: extend)
  f / t    find / till char (inclusive / exclusive)
  o / O    block / to end of block       m        select join region
  , / .    inner / bounds of thing       [ / ]    to beginning / end of thing
     things: r round  s square  c curly  g string  e symbol  w window
             b buffer  p paragraph  l line  v visual line  d defun  . sentence
  1-9, 0   expand selection by N units (0 = 10); without selection: count
  -        negative argument              ;        reverse selection
  i / a    insert at start / end          I / A    open line above / below
  c        change                         s        kill (cut)
  d / D    delete char/sel fwd / back     y        save (copy)
  p        yank (paste at point)          r        replace selection with clipboard
  u        undo                           '        repeat last command
  v        visit (regexp search+select)   n        search next (reversed sel = backward)
  z        pop selection (or grab)        g        cancel selection / cursors
  G        grab (secondary selection)     R / Y    swap grab / sync grab
  Q / X    goto line                      q        close window
  S        avy: type chars, home-row labels jump anywhere on screen
  ESC      insert -> normal; drops extra cursors
  BEACON   grab a region (G), then select w/x/f... inside it:
           a cursor lands on every match — edit them all, ESC to finish

EMACS CHORDS (Neovim keymaps, not rc-configurable)
  C-f/b/n/p  char/line move            C-a/e      beginning/end of line
  M-f/b      word move                 M-a/e      backward/forward sentence
  M-< / M->  buffer boundary           M-{ / M-}  paragraph move
  M-u/l/c    up/down/capitalize word   M-d        kill word
             no selection: just moves; with one active: extends it
             (point motion over an active Emacs mark) — same rule ; reverses

KEYPAD (SPC — or Alt+; from ANY state, INSERT included; returns there)
  SPC b buffers   SPC x file/buffer/window   SPC c commands   SPC m meta
  SPC w windows   SPC 0-9 count   SPC ? this sheet   SPC / describe key
  SPC c m open the neomeow.lua settings file   SPC c M reload it
  REPEAT  some entries start a run (Emacs repeat-mode): after
          SPC . e keep tapping . / , to walk diagnostics, after SPC w i
          keep tapping i (or = - o u 0) to keep zooming — any other
          key ends the run and keeps its normal meaning

neomeow.lua settings: return { rc = { 'nmap <key> <action>(command)',
  'nmap <key> meow-command', 'nmap <key> <meow keys>', 'mmap ... (MOTION)',
  'map <leader><seq> ...', 'desc <leader><seq> text', 'set nowhich-key',
  'repeat <group> <key> <target>' } } — every binding above is an rc line;
  the defaults ship as a bundled .neomeowrc inside the plugin; the settings
  file overrides them key by key
]]):match('^%s*(.-)%s*$')

local function describe(ctx, prefix)
  local descsMap = Rc.keypadDescs()
  local map, order = Rc.keypad()
  local seqs = {}
  for _, seq in ipairs(order) do
    if seq:sub(1, #prefix) == prefix then
      table.insert(seqs, seq)
    end
  end
  table.sort(seqs)
  local lines = {}
  for _, seq in ipairs(seqs) do
    local binding = map[seq]
    local target = binding.action or binding.command or binding.keys or ''
    local desc = ''
    if descsMap[seq] ~= nil then
      desc = '  (' .. descsMap[seq] .. ')'
    end
    table.insert(lines, 'SPC ' .. seq:gsub('.', '%0 '):sub(1, -2) .. '  ->  ' .. target .. desc)
  end
  local body = table.concat(lines, '\n')
  if body == '' then
    body = 'SPC ' .. prefix .. ' is undefined'
  end
  ctx.ui:info('Meow Describe: SPC ' .. prefix, body)
end

function M.exit(ctx)
  ctx.ui:hideWhichKey()
  port_.setMode(ctx, ctx.state.keypadPreviousState)
end

function M.key(ctx, char)
  local state = ctx.state
  ctx.ui:hideWhichKey()
  local map, order = Rc.keypad()
  local buf = state.keypad

  if buf == '/' then
    describe(ctx, char)
    M.exit(ctx)
    return
  end
  if buf == '' then
    if char >= '0' and char <= '9' then
      state.pendingCount = state.pendingCount * 10 + (char:byte() - string.byte('0'))
      M.exit(ctx)
      return
    end
    if char == '?' then
      M.exit(ctx)
      ctx.ui:info('Meow Cheatsheet', M.CHEATSHEET)
      return
    end
    if char == '/' then
      state.keypad = state.keypad .. '/'
      return
    end
  end

  state.keypad = state.keypad .. char
  local cur = state.keypad
  local binding = map[cur]
  if binding ~= nil then
    M.exit(ctx)
    require('neomeow.core.engine').runBinding(ctx, binding)
    return
  end
  local hasPrefix = false
  for _, seq in ipairs(order) do
    if seq:sub(1, #cur) == cur then
      hasPrefix = true
      break
    end
  end
  if not hasPrefix then
    M.exit(ctx)
    ctx.ui:hint('SPC ' .. cur:gsub('.', '%0 '):sub(1, -2) .. ' is undefined')
  else
    ctx.ui:scheduleWhichKey('keypad', cur)
  end
end

return M
