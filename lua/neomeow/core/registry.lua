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

M.COMMANDS = {}

function M.register(commands)
  for name, fn in pairs(commands) do
    M.COMMANDS[name] = fn
  end
end

M.register({
  ['meow-negative-argument'] = function(ctx)
    ctx.st.negative = true
  end,
  ['negative-argument'] = function(ctx)
    ctx.st.negative = true
  end,
  ['meow-quit'] = function(ctx)
    ctx.port:closeEditor()
  end,
  ['ignore'] = function() end,
})

return M
