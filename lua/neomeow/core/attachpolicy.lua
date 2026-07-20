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

local READONLY_SURFACES = {
  ['help'] = true,
}

local SKIP_SURFACES = {
  ['terminal'] = true,
  ['prompt'] = true,
  ['quickfix'] = true,
  ['nofile'] = true,
}

function M.attachMode(surface)
  if SKIP_SURFACES[surface] then
    return nil
  end
  return 'NORMAL'
end

function M.isWritableSurface(surface)
  return not READONLY_SURFACES[surface]
end

return M
