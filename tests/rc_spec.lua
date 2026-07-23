-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local Rc = require('neomeow.core.rc')
local RcState = require('neomeow.core.rcstate')
local keypadRows = require('neomeow.core.whichkey').keypadRows
local MeowMode = h.MeowMode

local function size(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

local function some(rows, k, label)
  for _, r in ipairs(rows) do
    if r[1] == k and r[2] == label then
      return true
    end
  end
  return false
end

local QWERTY = {
  ['0'] = 'meow-expand-0',
  ['1'] = 'meow-expand-1',
  ['2'] = 'meow-expand-2',
  ['3'] = 'meow-expand-3',
  ['4'] = 'meow-expand-4',
  ['5'] = 'meow-expand-5',
  ['6'] = 'meow-expand-6',
  ['7'] = 'meow-expand-7',
  ['8'] = 'meow-expand-8',
  ['9'] = 'meow-expand-9',
  ['-'] = 'meow-negative-argument',
  [';'] = 'meow-reverse',
  [','] = 'meow-inner-of-thing',
  ['.'] = 'meow-bounds-of-thing',
  ['['] = 'meow-beginning-of-thing',
  [']'] = 'meow-end-of-thing',
  ['<'] = 'meow-beginning-of-thing',
  ['>'] = 'meow-end-of-thing',
  ['a'] = 'meow-append',
  ['A'] = 'meow-open-below',
  ['b'] = 'meow-back-word',
  ['B'] = 'meow-back-symbol',
  ['c'] = 'meow-change',
  ['d'] = 'meow-delete',
  ['D'] = 'meow-backward-delete',
  ['e'] = 'meow-next-word',
  ['E'] = 'meow-next-symbol',
  ['f'] = 'meow-find',
  ['g'] = 'meow-cancel-selection',
  ['G'] = 'meow-grab',
  ['h'] = 'meow-left',
  ['H'] = 'meow-left-expand',
  ['i'] = 'meow-insert',
  ['I'] = 'meow-open-above',
  ['j'] = 'meow-next',
  ['J'] = 'meow-next-expand',
  ['k'] = 'meow-prev',
  ['K'] = 'meow-prev-expand',
  ['l'] = 'meow-right',
  ['L'] = 'meow-right-expand',
  ['m'] = 'meow-join',
  ['n'] = 'meow-search',
  ['o'] = 'meow-block',
  ['O'] = 'meow-to-block',
  ['p'] = 'meow-yank',
  ['q'] = 'meow-quit',
  ['Q'] = 'meow-goto-line',
  ['r'] = 'meow-replace',
  ['R'] = 'meow-swap-grab',
  ['s'] = 'meow-kill',
  ['t'] = 'meow-till',
  ['u'] = 'meow-undo',
  ['U'] = 'meow-undo-in-selection',
  ['v'] = 'meow-visit',
  ['w'] = 'meow-mark-word',
  ['W'] = 'meow-mark-symbol',
  ['x'] = 'meow-line',
  ['X'] = 'meow-goto-line',
  ['y'] = 'meow-save',
  ['Y'] = 'meow-sync-grab',
  ['z'] = 'meow-pop-selection',
  ["'"] = 'repeat',
}

describe('RcSpec', function()
  it('given an action mapping then it parses into a normal override', function()
    local c = Rc.parse({ 'nmap S <action>(extension.aceJump)' })
    h.eq(c.normal['S'].action, 'extension.aceJump')
    h.eqList(c.errors, {})
  end)

  it('given a key-sequence mapping then it parses as replay keys', function()
    local c = Rc.parse({ 'nmap Z ,b' })
    h.eq(c.normal['Z'].keys, ',b')
    h.eq(c.normal['Z'].recursive, true)
  end)

  it('given nnoremap then the binding is non-recursive', function()
    local c = Rc.parse({ 'nnoremap Z ,b' })
    h.eq(c.normal['Z'].recursive, false)
  end)

  it('given a meow command name then it parses into a command binding', function()
    local c = Rc.parse({
      'nmap n meow-mark-word',
      'nmap d ignore',
      'nmap Z repeat',
    })
    h.eq(c.normal['n'].command, 'meow-mark-word')
    h.eq(c.normal['d'].command, 'ignore')
    h.eq(c.normal['Z'].command, 'repeat')
    h.eqList(c.errors, {})
  end)

  it('given mmap then the binding lands in the motion map', function()
    local c = Rc.parse({ 'mmap n meow-next', 'mnoremap e k' })
    h.eq(c.motion['n'].command, 'meow-next')
    h.eq(c.motion['e'].keys, 'k')
    h.eq(c.motion['e'].recursive, false)
    h.eq(size(c.normal), 0)
    h.eqList(c.errors, {})
  end)

  it('given an unknown meow command then an error is collected', function()
    local c = Rc.parse({ 'nmap Z meow-frobnicate' })
    h.eq(#c.errors, 1)
    h.ok(c.errors[1]:find('meow-frobnicate', 1, true))
  end)

  it('given comment-only rc edits then the reload button reports no changes', function()
    h.freshSpec()
    Rc.setUserLines({ 'nmap Z ,b' })
    h.ok(RcState.equalTo(Rc.parse({ '" just a comment', 'nmap Z ,b' })))
    h.ok(not RcState.equalTo(Rc.parse({ 'nmap Q meow-goto-line' })))
  end)

  it('given a parameterized action then the whole serialized command is kept', function()
    local id = 'com.example.showView(com.example.viewId=com.example.SomeView,com.example.focus=true)'
    local c = Rc.parse({ 'map <leader>bj <action>(' .. id .. ')' })
    h.eq(c.keypad['bj'].action, id)
    h.eqList(c.errors, {})
  end)

  it('given leader mappings and descriptions then the keypad table extends', function()
    h.freshSpec()
    Rc.setForTest(Rc.parse(vim.split('map <leader>gd <action>(editor.action.revealDefinition)\ndesc <leader>g goto things', '\n', { plain = true })))
    h.eq(Rc.cfg().keypad['gd'].action, 'editor.action.revealDefinition')
    h.eq(Rc.cfg().keypadDesc['g'], 'goto things')
    h.eq((Rc.keypad())['gd'].action, 'editor.action.revealDefinition')
    h.eq((Rc.keypad())['mx'].action, "call feedkeys(':')")
  end)

  it('given the ideavimrc WhichKeyDesc let syntax then descriptions parse', function()
    local c = Rc.parse({ 'let g:WhichKeyDesc_leader_x = "<leader>x C-x files/buffers"' })
    h.eq(c.keypadDesc['x'], 'C-x files/buffers')
    h.eqList(c.errors, {})
  end)

  it('given a cmap or cnoremap line then the rc loads it without error', function()
    local c = Rc.parse({
      'cmap <C-h> backward-char',
      'cnoremap <C-x> <action>(SomeChord)',
      'nmap Z ,b',
    })
    h.eqList(c.errors, {})
    h.eq(c.normal['Z'].keys, ',b')
  end)

  it('given set lines then which-key options apply and vim options are ignored', function()
    local c = Rc.parse({
      'set nowhich-key',
      'set timeoutlen=400',
      'set clipboard+=unnamedplus',
      'let mapleader=" "',
    })
    h.eq(c.whichKey, false)
    h.eq(c.whichKeyDelayMs, 400)
    h.eqList(c.errors, {})
  end)

  it('which-key settings layer user over bundled defaults', function()
    h.freshSpec()
    h.eq(Rc.whichKeyEnabled(), true)
    h.eq(Rc.whichKeyDelayMs(), 300)
    Rc.setForTest(Rc.parse(vim.split('set nowhich-key\nset timeoutlen=150', '\n', { plain = true })))
    h.eq(Rc.whichKeyEnabled(), false)
    h.eq(Rc.whichKeyDelayMs(), 150)
  end)

  it('given a trailing comment then it is stripped from the line', function()
    local c = Rc.parse({
      'nmap S <action>(extension.aceJump)   " jump anywhere',
      'map <leader>zz ,b            " select the buffer',
    })
    h.eq(c.normal['S'].action, 'extension.aceJump')
    h.eq(c.keypad['zz'].keys, ',b')
    h.eqList(c.errors, {})
  end)

  it('the bundled default neomeowrc defines the whole keymap', function()
    h.freshSpec()
    local d = Rc.defaults()
    h.eqList(d.errors, {}, 'bundled default must parse clean')
    for key, cmd in pairs(QWERTY) do
      if key ~= 'Q' then
        h.eq(d.normal[key] and d.normal[key].command, cmd, "bundled layout line for '" .. key .. "'")
      end
    end
    h.eq(d.normal['Q'] and d.normal['Q'].command, 'avy-goto-line')
    h.eq(d.normal['S'] and d.normal['S'].command, 'avy-goto-char-timer')
    h.eq(d.motion['j'] and d.motion['j'].command, 'meow-next')
    h.eq(d.motion['k'] and d.motion['k'].command, 'meow-prev')
    h.eq(d.keypad['mx'] and d.keypad['mx'].action, "call feedkeys(':')")
    h.eq(d.keypad[' '] and d.keypad[' '].action, 'b #')
    h.eq(d.keypad['cm'] and d.keypad['cm'].action, 'NeomeowEditRc')
    h.eq(d.keypad['cM'] and d.keypad['cM'].action, 'NeomeowReloadRc')
    h.eq(d.keypad['rr'] and d.keypad['rr'].action, 'make')
    h.ok(size(d.keypad) > 60, 'keypad table + ported leader groups (got ' .. size(d.keypad) .. ')')
  end)

  it('given bad lines then errors are collected with line numbers', function()
    local c = Rc.parse({
      'frobnicate everything',
      'nmap <Space> ,b',
      'map <leader>1 <action>(X)',
      'nmap Q <CR>',
      'mmap <leader>x ,b',
    })
    h.eq(#c.errors, 5)
    h.ok(c.errors[1]:sub(1, 6) == 'line 1')
  end)

  it('given an rc key-sequence override then the key replays through the engine', function()
    local s = h.freshSpec()
    s:given('two words', 'on<caret>e two')
    s:givenRc('nmap Z ,b')
    s:whenKeys('Z')
    s:thenSelection('one two')
  end)

  it('given a recursive map then the RHS expands user maps', function()
    local s = h.freshSpec()
    s:given('two words', 'one two<caret>')
    s:givenRc('nmap B ,b\nnmap Y B')
    s:whenKeys('Y')
    s:thenSelection('one two')
  end)

  it('given nnoremap then the RHS runs the bundled default instead', function()
    local s = h.freshSpec()
    s:given('two words', 'one two<caret>')
    s:givenRc('nmap B ,b\nnnoremap Z B')
    s:whenKeys('Z')
    s:thenSelection('two')
  end)

  it('given a self-referencing map then recursion is depth-limited', function()
    local s = h.freshSpec()
    s:given('plain', '<caret>hello')
    s:givenRc('nmap Z Z')
    s:whenKeys('Z')
    s:thenText('hello')
  end)

  it('given an rc keypad mapping with keys then SPC seq replays them', function()
    local s = h.freshSpec()
    s:given('two words', 'on<caret>e two')
    s:givenRc('map <leader>k ,b')
    s:whenKeys(' k')
    s:thenSelection('one two')
    s:thenMode(MeowMode.NORMAL)
  end)

  it('given an rc keypad mapping then it overrides the bundled entry', function()
    local s = h.freshSpec()
    s:given('two words', 'on<caret>e two')
    s:givenRc('map <leader>bb ,b')
    s:whenKeys(' bb')
    s:thenSelection('one two')
  end)

  it('given a layout rebinding then the key runs the meow command', function()
    local s = h.freshSpec()
    s:given('two words', 'on<caret>e two')
    s:givenRc('nmap n meow-mark-word')
    s:whenKeys('n')
    s:thenSelection('one')
  end)

  it('given ignore then the key is disabled', function()
    local s = h.freshSpec()
    s:given('chars', '<caret>abc')
    s:givenRc('nmap d ignore')
    s:whenKeys('d')
    s:thenText('abc')
  end)

  it('given a motion rebinding then MOTION-state editors use it', function()
    local s = h.freshSpec()
    s:given('three lines', '<caret>one\ntwo\nthree')
    s:givenRc('mmap n meow-next')
    s.st.mode = MeowMode.MOTION
    s:whenKeys('n')
    h.eq(s:caretLine(), 1)
    s:whenKeys('j')
    h.eq(s:caretLine(), 2)
  end)

  it('given repeat on another key then it repeats the last command', function()
    local s = h.freshSpec()
    s:given('chars', '<caret>abcdef')
    s:givenRc('nmap Z repeat')
    s:whenKeys('d')
    s:thenText('bcdef')
    s:whenKeys('Z')
    s:thenText('cdef')
  end)

  it('given a mapped key when quote then the mapping repeats', function()
    local s = h.freshSpec()
    s:given('chars', '<caret>abcdef')
    s:givenRc('nmap Z d')
    s:whenKeys('Z')
    s:thenText('bcdef')
    s:whenKeys("'")
    s:thenText('cdef')
  end)

  it('given keypad entries then which-key rows show terminals and groups', function()
    local s = h.freshSpec()
    s:givenRc('map <leader>zz <action>(vim.lsp.buf.hover())\ndesc <leader>z my group')
    local top = keypadRows('')
    h.ok(some(top, 'z', 'my group'))
    local inner = keypadRows('z')
    h.ok(some(inner, 'z', 'vim.lsp.buf.hover()'))
  end)

  it('given a terminal with a description then which-key prefers it', function()
    local s = h.freshSpec()
    s:givenRc('map <leader>zz <action>(vim.lsp.buf.hover())\ndesc <leader>zz open a file')
    h.ok(some(keypadRows('z'), 'z', 'open a file'))
  end)

  it('given the default table then the SPC SPC entry renders as SPC', function()
    h.freshSpec()
    local found = false
    for _, r in ipairs(keypadRows('')) do
      if r[1] == 'SPC' then
        found = true
      end
    end
    h.ok(found)
  end)
end)
