-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local describe, it = h.describe, h.it
local Ace = require('neomeow.core.acewindow')
local windmove = require('neomeow.core.windmove')
local Resizes = require('neomeow.core.resize')
local Rc = require('neomeow.core.rc')

describe('WindmoveSpec', function()
  it('given window rectangles then ace-window orders them left to right then top down', function()
    h.eqList(
      Ace.ordered({
        { item = 'R', x = 40, y = 0 },
        { item = 'L2', x = 0, y = 12 },
        { item = 'L1', x = 0, y = 0 },
      }),
      { 'L1', 'L2', 'R' }
    )
  end)

  it('given one two or many windows then ace-window plans self other or labels', function()
    h.eq(Ace.plan(1), Ace.Plan.None)
    h.eq(Ace.plan(2), Ace.Plan.Other)
    h.eq(Ace.plan(3), Ace.Plan.Labels)
    h.eq(Ace.plan(9), Ace.Plan.Labels)
  end)

  it('given labelled windows then ace-window labels follow the avy subdivision', function()
    h.eqList(Ace.labels(3), { 'a', 's', 'd' })
    h.eqList(Ace.labels(0), {})
  end)

  it('given a typed prefix then ace-window keeps only the windows still matching', function()
    h.eqList(Ace.matches({ 'a', 's', 'la', 'ls' }, 'l'), { 'la', 'ls' })
    h.eqList(Ace.matches({ 'a', 's', 'la', 'ls' }, 'z'), {})
  end)

  it('given a direction then windmove plans the wincmd focus for it', function()
    h.eq(windmove.plan('left'), 'wincmd h')
    h.eq(windmove.plan('right'), 'wincmd l')
    h.eq(windmove.plan('up'), 'wincmd k')
    h.eq(windmove.plan('down'), 'wincmd j')
  end)

  it('given no window in the direction then the message is Emacs verbatim', function()
    h.eq(windmove.noWindowMessage('left'), 'No window left from selected window')
    h.eq(windmove.noWindowMessage('down'), 'No window down from selected window')
  end)

  it('given the bundled rc then SPC w hjkl dispatch windmove', function()
    h.freshSpec()
    local d = Rc.defaults().keypad
    h.eq(d['wh'].action, 'NeomeowWindmoveLeft')
    h.eq(d['wj'].action, 'NeomeowWindmoveDown')
    h.eq(d['wk'].action, 'NeomeowWindmoveUp')
    h.eq(d['wl'].action, 'NeomeowWindmoveRight')
  end)

  it('given the bundled rc then SPC w v splits the current window', function()
    h.freshSpec()
    h.eq(Rc.defaults().keypad['wv'].action, 'vsplit')
  end)

  it('given the bundled rc then SPC w w and SPC x o both arm ace-window', function()
    h.freshSpec()
    local d = Rc.defaults().keypad
    h.eq(d['ww'].action, 'NeomeowAceWindow')
    h.eq(d['xo'].action, 'NeomeowAceWindow')
    h.eq(d['wW'].action, 'NeomeowAceSwapWindow')
  end)

  it('given an ace slot then it never falls through to replayed keys', function()
    h.freshSpec()
    local d = Rc.defaults().keypad
    for _, slot in ipairs({ 'ww', 'wW', 'xo', 'wr' }) do
      h.eq(d[slot].keys, nil)
      h.eq(d[slot].action ~= nil or d[slot].command ~= nil, true)
    end
  end)

  it('given the bundled rc then SPC w r opens the ace-resize session', function()
    h.freshSpec()
    h.eq(Rc.defaults().keypad['wr'].action, 'NeomeowAceResize')
  end)

  it('given the bundled rc then the resize session binds the directional keys', function()
    h.freshSpec()
    local map, order = Rc.resizeBindings()
    h.eqList(order, { 'l', 'h', 'k', 'j', '=', 'm' })
    h.eq(map['l'].action, 'vertical resize +4')
    h.eq(map['h'].action, 'vertical resize -4')
    h.eq(map['k'].action, 'resize +2')
    h.eq(map['j'].action, 'resize -2')
    h.eq(map['='].action, 'wincmd =')
  end)

  it('given a resize key bound to ignore then the key leaves the session', function()
    local s = h.freshSpec()
    s:givenRc('resizemap m ignore')
    local _, order = Rc.resizeBindings()
    h.eqList(order, { 'l', 'h', 'k', 'j', '=' })
    h.eq(Resizes.bindingFor('m'), nil)
  end)

  it('given a resize key then dispatch runs its target and unknown keys end the session', function()
    local s = h.freshSpec()
    s:given('two lines', '<caret>one\ntwo')
    h.eq(Resizes.dispatch(s:ctx(), 'l'), true)
    h.eq(s.ui.ran[#s.ui.ran], 'vertical resize +4')
    h.eq(Resizes.dispatch(s:ctx(), 'Z'), false)
  end)
end)
