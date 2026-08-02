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

local savedConfig = nil

local function esc(value)
  return (tostring(value):gsub('[%%|;]', function(char)
    return '%' .. string.byte(char)
  end))
end

local function bindingRepr(binding)
  return table.concat({
    'a=' .. esc(binding.action == nil and '' or binding.action),
    'k=' .. esc(binding.keys == nil and '' or binding.keys),
    'c=' .. esc(binding.command == nil and '' or binding.command),
    'r=' .. tostring(binding.recursive),
  }, ',')
end

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

local function mapRepr(map, valueRepr)
  local parts = {}
  for _, key in ipairs(sortedKeys(map)) do
    table.insert(parts, esc(key) .. '=>' .. valueRepr(map[key]))
  end
  return table.concat(parts, ';')
end

local function serialize(config)
  local parts = {
    mapRepr(config.normal, bindingRepr),
    mapRepr(config.motion, bindingRepr),
    mapRepr(config.keypad, bindingRepr),
    mapRepr(config.keypadDesc, esc),
  }
  local groups = {}
  for _, group in ipairs(sortedKeys(config.repeatGroups)) do
    table.insert(groups, esc(group) .. '=>' .. mapRepr(config.repeatGroups[group].map, bindingRepr))
  end
  table.insert(parts, table.concat(groups, '&'))
  table.insert(parts, tostring(config.whichKey))
  table.insert(parts, tostring(config.whichKeyDelayMs))
  return table.concat(parts, '|')
end

function M.saveParsed(config)
  savedConfig = serialize(config)
end

function M.equalTo(config)
  return savedConfig ~= nil and serialize(config) == savedConfig
end

function M.resetForTest()
  savedConfig = nil
end

return M
