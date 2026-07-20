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

M.LABEL_THRESHOLD = 2

M.Plan = {
  None = 'none',
  Other = 'other',
  Labels = 'labels',
}

function M.plan(windowCount)
  if windowCount <= 1 then
    return M.Plan.None
  end
  if windowCount <= M.LABEL_THRESHOLD then
    return M.Plan.Other
  end
  return M.Plan.Labels
end

function M.ordered(candidates)
  local sorted = {}
  for i, c in ipairs(candidates) do
    sorted[i] = c
  end
  table.sort(sorted, function(a, b)
    if a.x ~= b.x then
      return a.x < b.x
    end
    return a.y < b.y
  end)
  local out = {}
  for i, c in ipairs(sorted) do
    out[i] = c.item
  end
  return out
end

return M
