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

local M = {}

M.RECENTER_COMMAND = 'recenter-top-bottom'

M.RECENTER_POSITIONS = { 'center', 'top', 'bottom' }

function M.recenterPosition(phase)
  return M.RECENTER_POSITIONS[phase % #M.RECENTER_POSITIONS + 1] or 'center'
end

function M.nextRecenterPhase(previousCommand, phase)
  if previousCommand == M.RECENTER_COMMAND then
    return phase + 1
  end
  return 0
end

M.commands = {
  [M.RECENTER_COMMAND] = function(ctx)
    ctx.st.recenterPhase = M.nextRecenterPhase(ctx.st.lastCommand, ctx.st.recenterPhase)
    ctx.st.lastCommand = M.RECENTER_COMMAND
    ctx.ui:revealCaret(M.recenterPosition(ctx.st.recenterPhase))
  end,
}

return M
