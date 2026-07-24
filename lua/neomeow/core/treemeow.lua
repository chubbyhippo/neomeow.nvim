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

local MAX_DISPATCH_DEPTH = 8

local LIST_MOTIONS = {
  ['meow-next'] = 'neomeow.tree.focusDown',
  ['meow-prev'] = 'neomeow.tree.focusUp',
  ['meow-left'] = 'neomeow.tree.collapse',
  ['meow-right'] = 'neomeow.tree.expand',
}

function M.boundChars()
  local out = {}
  local function consider(c)
    local b = Rc.cfg().motion[c]
    if b == nil then
      b = Rc.defaults().motion[c]
    end
    if b ~= nil and b.command ~= 'ignore' then
      out[c] = true
    end
  end
  for c in pairs(Rc.defaults().motion) do
    consider(c)
  end
  for c in pairs(Rc.cfg().motion) do
    consider(c)
  end
  return out
end

function M.dispatch(run, c, noremap, depth)
  noremap = noremap or false
  depth = depth or 0
  local b = nil
  if not noremap then
    b = Rc.cfg().motion[c]
  end
  if b == nil then
    b = Rc.defaults().motion[c]
  end
  if b == nil then
    return
  end
  if b.command ~= nil then
    local listCommand = LIST_MOTIONS[b.command]
    if listCommand ~= nil then
      run(listCommand)
    end
    return
  end
  if b.action ~= nil then
    run(b.action)
    return
  end
  if b.keys == nil then
    return
  end
  if depth >= MAX_DISPATCH_DEPTH then
    return
  end
  for i = 1, #b.keys do
    M.dispatch(run, b.keys:sub(i, i), noremap or not b.recursive, depth + 1)
  end
end

return M
