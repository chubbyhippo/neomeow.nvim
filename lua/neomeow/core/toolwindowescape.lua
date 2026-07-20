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

M.TIMEOUT_MS = 500

local lastSurface = nil
local lastAt = 0

function M.onEscape(surface, at)
  local doubled = surface ~= nil and surface == lastSurface and at - lastAt <= M.TIMEOUT_MS
  if doubled then
    M.reset()
    return true
  end
  lastSurface = surface
  lastAt = at
  return false
end

function M.reset()
  lastSurface = nil
  lastAt = 0
end

return M
