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

local Rc = require('neomeow.core.rc')

local M = {}

function M.keys()
  local _, order = Rc.resizeBindings()
  return order
end

function M.bindingFor(key)
  local map, order = Rc.resizeBindings()
  for _, bound in ipairs(order) do
    if bound == key then
      return map[key]
    end
  end
  return nil
end

function M.dispatch(ctx, key)
  local binding = M.bindingFor(key)
  if binding == nil then
    return false
  end
  require('neomeow.core.engine').runBinding(ctx, binding)
  return true
end

return M
