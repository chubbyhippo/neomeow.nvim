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

local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
package.path = table.concat({
  root .. '/?.lua',
  root .. '/lua/?.lua',
  root .. '/lua/?/init.lua',
  root .. '/tests/?.lua',
  package.path,
}, ';')

local suite = require('tests.suite')

local files = vim.fn.glob(root .. '/tests/*_spec.lua', false, true)
table.sort(files)
for _, f in ipairs(files) do
  dofile(f)
end

local totalPassed = 0
local totalFailed = 0
for _, s in ipairs(suite.results()) do
  totalPassed = totalPassed + s.passed
  totalFailed = totalFailed + #s.failures
  local mark = #s.failures == 0 and 'ok' or 'FAIL'
  io.write(string.format('%-24s %3d passed %3d failed  %s\n', s.name, s.passed, #s.failures, mark))
  for _, f in ipairs(s.failures) do
    io.write('  ✗ ' .. f.name .. '\n')
    io.write('    ' .. f.err:gsub('\n', '\n    ') .. '\n')
  end
end
io.write(string.format('total: %d passed, %d failed\n', totalPassed, totalFailed))
if totalFailed > 0 then
  os.exit(1)
end
