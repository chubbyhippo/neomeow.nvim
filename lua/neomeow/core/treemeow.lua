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

local function motionBinding(char, noremap)
  local binding = nil
  if not noremap then
    binding = Rc.cfg().motion[char]
  end
  if binding == nil then
    binding = Rc.defaults().motion[char]
  end
  return binding
end

function M.boundChars()
  local out = {}
  local function consider(char)
    local binding = motionBinding(char, false)
    if binding ~= nil and binding.command ~= 'ignore' then
      out[char] = true
    end
  end
  for char in pairs(Rc.defaults().motion) do
    consider(char)
  end
  for char in pairs(Rc.cfg().motion) do
    consider(char)
  end
  return out
end

function M.dispatch(run, char, noremap, depth)
  noremap = noremap or false
  depth = depth or 0
  local binding = motionBinding(char, noremap)
  if binding == nil then
    return
  end
  if binding.command ~= nil then
    local listCommand = LIST_MOTIONS[binding.command]
    if listCommand ~= nil then
      run(listCommand)
    end
    return
  end
  if binding.action ~= nil then
    run(binding.action)
    return
  end
  if binding.keys == nil then
    return
  end
  if depth >= MAX_DISPATCH_DEPTH then
    return
  end
  for i = 1, #binding.keys do
    M.dispatch(run, binding.keys:sub(i, i), noremap or not binding.recursive, depth + 1)
  end
end

return M
