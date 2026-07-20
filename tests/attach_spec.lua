-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local attachpolicy = require('neomeow.core.attachpolicy')
local MeowMode = h.MeowMode

describe('AttachSpec', function()
  it('given a file editor then meow attaches in NORMAL', function()
    h.eq(attachpolicy.attachMode('file-editor'), MeowMode.NORMAL)
  end)

  it('given a help buffer then NORMAL, reported read-only', function()
    h.eq(attachpolicy.attachMode('help'), MeowMode.NORMAL)
    h.eq(attachpolicy.isWritableSurface('help'), false)
  end)

  it('given terminal and prompt buffers then meow stays away', function()
    h.eq(attachpolicy.attachMode('terminal'), nil)
    h.eq(attachpolicy.attachMode('prompt'), nil)
  end)

  it('given quickfix and nofile scratch buffers then meow stays away', function()
    h.eq(attachpolicy.attachMode('quickfix'), nil)
    h.eq(attachpolicy.attachMode('nofile'), nil)
  end)
end)
