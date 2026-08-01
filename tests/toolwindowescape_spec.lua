-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local describe, it = h.describe, h.it
local Engine = require('neomeow.core.engine')
local twe = require('neomeow.core.toolwindowescape')
local onEscape, reset, TIMEOUT_MS = twe.onEscape, twe.reset, twe.TIMEOUT_MS
local MeowMode = h.MeowMode

describe('ToolWindowEscapeSpec', function()
  local navRc = table.concat({
    'map <leader>tn meow-next',
    'repeat nav . meow-next',
    'repeat nav , meow-prev',
  }, '\n')

  it('given a single escape in a tool window then it does not jump', function()
    reset()
    h.eq(onEscape('terminal', 1000), false)
  end)

  it('given a second escape in the same tool window within the timeout then it jumps', function()
    reset()
    onEscape('terminal', 1000)
    h.eq(onEscape('terminal', 1000 + TIMEOUT_MS), true)
  end)

  it('given a completed jump then the next escape starts a new pair', function()
    reset()
    onEscape('terminal', 1000)
    h.eq(onEscape('terminal', 1100), true)
    h.eq(onEscape('terminal', 1200), false)
  end)

  it('given escapes slower than the timeout then they do not pair but re-arm', function()
    reset()
    onEscape('terminal', 1000)
    h.eq(onEscape('terminal', 1001 + TIMEOUT_MS), false)
    h.eq(onEscape('terminal', 1200 + TIMEOUT_MS), true)
  end)

  it('given escapes in different tool windows then they do not pair', function()
    reset()
    onEscape('terminal', 1000)
    h.eq(onEscape('list', 1100), false)
    h.eq(onEscape('list', 1200), true)
  end)

  it('given focus outside any tool window then the pair breaks', function()
    reset()
    onEscape('terminal', 1000)
    h.eq(onEscape(nil, 1100), false)
    h.eq(onEscape('terminal', 1200), false)
  end)

  it("given KEYPAD then escape is meow's and exits the keypad", function()
    local s = h.freshSpec()
    s:given('keypad escape', '<caret>hello')
    s:whenKeys(' ')
    s:thenMode(MeowMode.KEYPAD)
    h.eq(s:pressEsc(), true)
    s:thenMode(MeowMode.NORMAL)
  end)

  it("given an active selection then escape is meow's and clears it", function()
    local s = h.freshSpec()
    s:given('selection escape', '<caret>hello world')
    s:whenKeys('w')
    h.neq(s:selectedText(), nil)
    h.eq(s:pressEsc(), true)
    h.eq(s:selectedText(), nil)
  end)

  it("given an armed repeat run then escape is meow's and ends it", function()
    local s = h.freshSpec()
    s:given('four lines', '<caret>one\ntwo\nthree\nfour')
    s:givenRc(navRc)
    s:whenKeys(' tn')
    h.neq(Engine.repeatMap, nil)
    h.eq(s:pressEsc(), true)
    h.eq(Engine.repeatMap, nil)
  end)

  it("given NORMAL with nothing to cancel then escape is not meow's", function()
    local s = h.freshSpec()
    s:given('idle escape', '<caret>hello')
    h.eq(s:pressEsc(), false)
  end)

  it("given INSERT then escape is meow's and returns to NORMAL", function()
    local s = h.freshSpec()
    s:given('insert escape', '<caret>hello')
    s:whenKeys('i')
    s:thenMode(MeowMode.INSERT)
    h.eq(s:pressEsc(), true)
    s:thenMode(MeowMode.NORMAL)
  end)
end)
