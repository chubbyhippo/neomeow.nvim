-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local Engine = require('neomeow.core.engine')
local Rc = require('neomeow.core.rc')
local RcState = require('neomeow.core.rcstate')
local state = require('neomeow.core.state')
local MeowMode = h.MeowMode
local Pending = h.Pending

local function sameSet(list, expected)
  local seen = {}
  for _, k in ipairs(list) do
    seen[k] = true
  end
  if #list ~= #expected then
    return false
  end
  for _, k in ipairs(expected) do
    if not seen[k] then
      return false
    end
  end
  return true
end

describe('RepeatSpec', function()
  local navRc = table.concat({
    'map <leader>tn meow-next',
    'repeat nav . meow-next',
    'repeat nav , meow-prev',
  }, '\n')

  it('given repeat lines then named groups parse with their member targets', function()
    local c = Rc.parse({
      'repeat nav . meow-next',
      'repeat nav , meow-prev',
      'repeat zoom i <action>(editor.action.fontZoomIn)',
    })
    h.eq(c.repeatGroups['nav'].map['.'].command, 'meow-next')
    h.eq(c.repeatGroups['nav'].map[','].command, 'meow-prev')
    h.eq(c.repeatGroups['zoom'].map['i'].action, 'editor.action.fontZoomIn')
    h.eqList(c.errors, {})
  end)

  it('given a repeat line with a bad target then an error is collected', function()
    local c = Rc.parse({ 'repeat nav . meow-frobnicate', 'repeat nav' })
    h.eq(#c.errors, 2)
    h.ok(c.errors[1]:find('meow-frobnicate', 1, true))
  end)

  it('given a repeat key that is not a single printable key then an error is collected', function()
    local c = Rc.parse({
      'repeat nav ab meow-next',
      'repeat nav <Space> meow-next',
    })
    h.eq(#c.errors, 2)
  end)

  it('given home rc repeat lines then they layer per key over the bundled group', function()
    h.freshSpec()
    Rc.setForTest(Rc.parse(vim.split('repeat zoom , meow-prev\nrepeat zoom e <action>(application:toggle-header)', '\n', { plain = true })))
    local g = (Rc.repeatGroups())['zoom']
    h.eq(g.map['i'].action, 'resize +2')
    h.eq(g.map[','].command, 'meow-prev')
    h.eq(g.map['e'].action, 'application:toggle-header')
  end)

  it('given a repeat member bound to ignore then the key is given back', function()
    h.freshSpec()
    Rc.setForTest(Rc.parse({ 'repeat zoom 0 ignore' }))
    local g = (Rc.repeatGroups())['zoom']
    h.eq(g.map['0'] ~= nil, false)
    h.eq(g.map['i'].action, 'resize +2')
  end)

  it('the bundled default neomeowrc declares the init el repeat groups', function()
    h.freshSpec()
    local d = Rc.defaults().repeatGroups
    h.ok(sameSet(d['zoom'].order, { 'i', '=', 'o', '-', 'u', '0' }))
    h.eq(d['zoom'].map['i'].action, 'resize +2')
    h.eq(d['zoom'].map['u'].action, 'wincmd =')
  end)

  it('given the bundled rc then the tab repeat group cycles editor tabs', function()
    h.freshSpec()
    local d = Rc.defaults().repeatGroups
    h.eq(d['tab'].map['n'].action, 'bnext')
    h.eq(d['tab'].map['p'].action, 'bprevious')
    h.eq(d['tab'].map['.'].action, 'bnext')
    h.eq(d['tab'].map[','].action, 'bprevious')
    h.ok(sameSet(d['tab'].order, { 'n', 'p', '.', ',' }))
  end)

  it('given a repeat line edit then the reload button sees a change', function()
    h.freshSpec()
    Rc.setUserLines({ 'nmap Z ,b' })
    h.ok(not RcState.equalTo(Rc.parse({ 'nmap Z ,b', 'repeat nav . meow-next' })))
  end)

  it('given a keypad nav entry in a repeat group then tapping the members keeps walking', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.eq(s:caretLine(), 1)
    s:whenKeys('.')
    h.eq(s:caretLine(), 2)
    s:whenKeys('.')
    h.eq(s:caretLine(), 3)
    s:whenKeys(',')
    h.eq(s:caretLine(), 2)
    s:thenMode(MeowMode.NORMAL)
  end)

  it('given a normal key bound to a member target then it arms the same run', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys('j')
    h.eq(s:caretLine(), 1)
    s:whenKeys('.')
    h.eq(s:caretLine(), 2)
  end)

  it('given a run then a member tap continues after an editor switch', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.eq(s:caretLine(), 1)
    s.st = state.newState()
    s:whenKeys('.')
    h.eq(s:caretLine(), 2)
  end)

  it('given a non-member key then the run ends and the key keeps its normal meaning', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.neq(Engine.repeatMap, nil)
    s:whenKeys('w')
    s:thenSelection('two')
    h.eq(Engine.repeatMap, nil)
  end)

  it('given the run over then the member keys mean their normal commands again', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    s:whenKeys('x')
    s:thenSelection('two')
    s:whenKeys('.')
    h.eq(s.st.pending, Pending.BOUNDS)
    h.eq(s:caretLine(), 1)
  end)

  it('given escape then the run ends', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.neq(Engine.repeatMap, nil)
    s:pressEsc()
    h.eq(Engine.repeatMap, nil)
    s:whenKeys('.')
    h.eq(s.st.pending, Pending.BOUNDS)
    h.eq(s:caretLine(), 1)
  end)

  it('given SPC during a run then the keypad still opens', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    s:whenKeys(' tn')
    h.eq(s:caretLine(), 2)
    s:thenMode(MeowMode.NORMAL)
  end)

  it('given a digit during a run then it falls through as a count', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.eq(s:caretLine(), 1)
    s:whenKeys('2j')
    h.eq(s:caretLine(), 3)
  end)

  it('given a run then the armed keys are the group members', function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.ok(sameSet(Engine.repeatMap.order, { '.', ',' }))
    s:whenKeys('w')
    h.eq(Engine.repeatMap, nil)
  end)

  it('given the bundled rc then SPC x z repeats the last command and bare z keeps repeating like Emacs C-x z', function()
    local s = h.freshSpec()
    s:given('delete run', '<caret>aaaaa')
    s:whenKeys('d')
    s:thenText('aaaa')
    s:whenKeys(' xz')
    s:thenText('aaa')
    s:whenKeys('z')
    s:thenText('aa')
    s:whenKeys('z')
    s:thenText('a')
    s:thenMode(MeowMode.NORMAL)
  end)
end)
