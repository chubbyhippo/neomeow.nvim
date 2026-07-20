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

local WINCMD = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

function M.wincmdLetter(dir)
  return WINCMD[dir]
end

function M.plan(dir)
  return 'wincmd ' .. WINCMD[dir]
end

function M.noWindowMessage(dir)
  return 'No window ' .. dir .. ' from selected window'
end

return M
