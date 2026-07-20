-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local Ace = require('neomeow.core.acewindow')
local windmove = require('neomeow.core.windmove')
local Rc = require('neomeow.core.rc')

describe('WindmoveSpec', function()
  it('given window rectangles then ace-window orders them left to right then top down', function()
    h.eqList(Ace.ordered({
      { item = 'R', x = 40, y = 0 },
      { item = 'L2', x = 0, y = 12 },
      { item = 'L1', x = 0, y = 0 },
    }), { 'L1', 'L2', 'R' })
  end)

  it('given one two or many windows then ace-window plans self other or labels', function()
    h.eq(Ace.plan(1), Ace.Plan.None)
    h.eq(Ace.plan(2), Ace.Plan.Other)
    h.eq(Ace.plan(3), Ace.Plan.Labels)
    h.eq(Ace.plan(9), Ace.Plan.Labels)
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
end)
