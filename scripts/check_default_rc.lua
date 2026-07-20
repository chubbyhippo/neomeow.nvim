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

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local src = assert(io.open(root .. '/.neomeowrc', 'r'))
local content = src:read('*a')
src:close()
content = content:gsub('\r\n', '\n'):gsub('\r', '\n')
content = content:gsub('\n$', '') .. '\n'

if require('neomeow.default_rc') == content then
  io.write('default_rc.lua is in sync with .neomeowrc\n')
else
  io.write('ERROR: default_rc.lua is stale — run: nvim -l scripts/gen_default_rc.lua\n')
  os.exit(1)
end
