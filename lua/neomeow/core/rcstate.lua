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

local state = nil

local function esc(s)
  return (tostring(s):gsub('[%%|;]', function(ch)
    return '%' .. string.byte(ch)
  end))
end

local function bindingRepr(b)
  return table.concat({
    'a=' .. esc(b.action == nil and '' or b.action),
    'k=' .. esc(b.keys == nil and '' or b.keys),
    'c=' .. esc(b.command == nil and '' or b.command),
    'r=' .. tostring(b.recursive),
  }, ',')
end

local function sortedKeys(map)
  local keys = {}
  for k in pairs(map) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

local function mapRepr(map, valueRepr)
  local parts = {}
  for _, k in ipairs(sortedKeys(map)) do
    table.insert(parts, esc(k) .. '=>' .. valueRepr(map[k]))
  end
  return table.concat(parts, ';')
end

local function serialize(c)
  local parts = {
    mapRepr(c.normal, bindingRepr),
    mapRepr(c.motion, bindingRepr),
    mapRepr(c.keypad, bindingRepr),
    mapRepr(c.keypadDesc, esc),
  }
  local groups = {}
  for _, g in ipairs(sortedKeys(c.repeatGroups)) do
    table.insert(groups, esc(g) .. '=>' .. mapRepr(c.repeatGroups[g].map, bindingRepr))
  end
  table.insert(parts, table.concat(groups, '&'))
  table.insert(parts, tostring(c.whichKey))
  table.insert(parts, tostring(c.whichKeyDelayMs))
  return table.concat(parts, '|')
end

function M.saveParsed(c)
  state = serialize(c)
end

function M.equalTo(c)
  return state ~= nil and serialize(c) == state
end

function M.resetForTest()
  state = nil
end

return M
