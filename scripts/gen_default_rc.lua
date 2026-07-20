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

local src = assert(io.open(root .. '/.neomeowrc', 'r'))
local content = src:read('*a')
src:close()
content = content:gsub('\r\n', '\n'):gsub('\r', '\n')
content = content:gsub('\n$', '') .. '\n'

local level = ''
while content:find(']' .. level .. ']', 1, true) or content:find('[' .. level .. '[', 1, true) do
  level = level .. '='
end

local header = table.concat({
  '-- Copyright (C) 2026 Chubby Hippo',
  '-- SPDX-License-Identifier: GPL-3.0-or-later',
  '-- (see LICENSE for the full GPL-3.0-or-later text)',
  '--',
  '-- Generated from .neomeowrc by scripts/gen_default_rc.lua — edit the rc, not this.',
  '',
  '',
}, '\n')

local out = assert(io.open(root .. '/lua/neomeow/default_rc.lua', 'w'))
out:write(header .. 'return [' .. level .. '[\n' .. content .. ']' .. level .. ']\n')
out:close()

io.write(string.format('wrote lua/neomeow/default_rc.lua (%d bytes, bracket level "%s")\n', #content, level))
