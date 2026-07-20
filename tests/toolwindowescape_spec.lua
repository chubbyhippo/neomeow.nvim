-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local twe = require('neomeow.core.toolwindowescape')
local onEscape, reset, TIMEOUT_MS = twe.onEscape, twe.reset, twe.TIMEOUT_MS

describe('ToolWindowEscapeSpec', function()
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
end)
