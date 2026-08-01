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

local Chord = require('neomeow.core.chord')
local Rc = require('neomeow.core.rc')
local MeowMode = require('neomeow.core.state').MeowMode

local M = {}

function M.takesChords(mode)
  return mode == MeowMode.NORMAL or mode == MeowMode.MOTION
end

function M.bindingFor(chord)
  if chord == nil then
    return nil
  end
  local map = Rc.chordBindings()
  return map[Chord.spelling(chord)]
end

function M.claims(mode, chord)
  return M.takesChords(mode) and M.bindingFor(chord) ~= nil
end

function M.dispatch(ctx, chord)
  if not M.claims(ctx.st.mode, chord) then
    return false
  end
  local binding = M.bindingFor(chord)
  if binding == nil then
    return false
  end
  require('neomeow.core.engine').runBinding(ctx, binding)
  return true
end

return M
