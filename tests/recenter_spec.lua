-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local describe, it = h.describe, h.it
local Chord = require('neomeow.core.chord')
local Chords = require('neomeow.core.chords')
local Rc = require('neomeow.core.rc')
local View = require('neomeow.core.view')

local BUFFER = 'one\ntwo\nthree<caret>\nfour\nfive\n'

describe('RecenterSpec', function()
  it('given the recenter cycle then the positions follow Emacs recenter-positions', function()
    h.eqList({
      View.recenterPosition(0),
      View.recenterPosition(1),
      View.recenterPosition(2),
      View.recenterPosition(3),
    }, { 'center', 'top', 'bottom', 'center' })
  end)

  it('given a different previous command then the recenter cycle starts over', function()
    h.eq(View.nextRecenterPhase(View.RECENTER_COMMAND, 0), 1)
    h.eq(View.nextRecenterPhase(View.RECENTER_COMMAND, 2), 3)
    h.eq(View.nextRecenterPhase('meow-left', 2), 0)
    h.eq(View.nextRecenterPhase(nil, 2), 0)
  end)

  it('given repeated C-l then the view cycles center top bottom like Emacs', function()
    local s = h.freshSpec()
    s:given('a caret mid-buffer', BUFFER)
    for _ = 1, 4 do
      s:whenCommand(View.RECENTER_COMMAND)
    end
    h.eqList(s.ui.revealed, { 'center', 'top', 'bottom', 'center' })
  end)

  it('given a motion between two C-l then the second one centers again', function()
    local s = h.freshSpec()
    s:given('a caret mid-buffer', BUFFER)
    s:whenCommand(View.RECENTER_COMMAND)
    s:whenKeys('h')
    s:whenCommand(View.RECENTER_COMMAND)
    h.eqList(s.ui.revealed, { 'center', 'center' })
  end)

  it('given the bundled rc then C-l runs recenter-top-bottom', function()
    h.freshSpec()
    h.eq(Chords.bindingFor(Chord.parse('C-l')).command, View.RECENTER_COMMAND)
    local map = Rc.chordBindings()
    h.eq(map['C-l'].command, View.RECENTER_COMMAND)
  end)
end)
