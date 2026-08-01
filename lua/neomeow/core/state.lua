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

M.MeowMode = {
  NORMAL = 'NORMAL',
  INSERT = 'INSERT',
  MOTION = 'MOTION',
  KEYPAD = 'KEYPAD',
}

M.SelType = {
  NONE = 'NONE',
  CHAR = 'CHAR',
  WORD = 'WORD',
  SYMBOL = 'SYMBOL',
  LINE = 'LINE',
  BLOCK = 'BLOCK',
  FIND = 'FIND',
  TILL = 'TILL',
  VISIT = 'VISIT',
  JOIN = 'JOIN',
  TRANSIENT = 'TRANSIENT',
}

M.Pending = {
  FIND = 'FIND',
  TILL = 'TILL',
  INNER = 'INNER',
  BOUNDS = 'BOUNDS',
  BEGIN = 'BEGIN',
  END_ = 'END',
}

local MeowState = {}
MeowState.__index = MeowState

function M.newState()
  return setmetatable({
    mode = M.MeowMode.NORMAL,
    selType = M.SelType.NONE,
    selExpand = false,
    pending = nil,

    pendingCount = 0,
    negative = false,

    lastFind = nil,

    searchHistory = {},

    selectionHistory = {},

    lastSelection = nil,

    goalColumn = nil,

    lastCommand = nil,
    recenterPhase = 0,

    grab = nil,

    avy = nil,

    aceWindow = nil,

    keypad = '',

    keypadPreviousState = M.MeowMode.NORMAL,

    unit = {},
    lastKeys = {},
    replaying = false,

    replayDepth = 0,
    noremapDepth = 0,
  }, MeowState)
end

function MeowState:takeCount(default)
  local def = default == nil and 1 or default
  local n = self.pendingCount == 0 and def or self.pendingCount
  local r = self.negative and -n or n
  self.pendingCount = 0
  self.negative = false
  return r
end

return M
