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

local rcParser = require('neomeow.core.rcparser')
local rcState = require('neomeow.core.rcstate')

local M = {}

M.FILE_NAME = '.neomeowrc'
M.USER_FILE_NAME = 'neomeow.lua'

local DEFAULT_WHICH_KEY_DELAY_MS = 250

local userConfig = rcParser.newConfig()
local defaultConfig = rcParser.newConfig()

M.newConfig = rcParser.newConfig

function M.parse(lines)
  return rcParser.parse(lines)
end

function M.initDefaults(lines)
  defaultConfig = rcParser.parse(lines)
  return defaultConfig
end

function M.setUserLines(lines)
  userConfig = rcParser.parse(lines)
  rcState.saveParsed(userConfig)
  return userConfig
end

function M.setForTest(c)
  userConfig = c
  rcState.resetForTest()
end

function M.cfg()
  return userConfig
end

function M.defaults()
  return defaultConfig
end

local function mergedOrdered(defMap, defOrder, userMap, userOrder)
  local map = {}
  local order = {}
  for _, k in ipairs(defOrder) do
    if map[k] == nil then
      table.insert(order, k)
    end
    map[k] = defMap[k]
  end
  for _, k in ipairs(userOrder) do
    if map[k] == nil then
      table.insert(order, k)
    end
    map[k] = userMap[k]
  end
  return map, order
end

function M.keypad()
  return mergedOrdered(defaultConfig.keypad, defaultConfig.keypadOrder, userConfig.keypad, userConfig.keypadOrder)
end

function M.keypadDescs()
  return mergedOrdered(
    defaultConfig.keypadDesc,
    defaultConfig.keypadDescOrder,
    userConfig.keypadDesc,
    userConfig.keypadDescOrder
  )
end

function M.repeatGroups()
  local merged = {}
  local order = {}
  for _, group in ipairs(defaultConfig.repeatOrder) do
    local src = defaultConfig.repeatGroups[group]
    local members = { map = {}, order = {} }
    for _, k in ipairs(src.order) do
      members.map[k] = src.map[k]
      table.insert(members.order, k)
    end
    merged[group] = members
    table.insert(order, group)
  end
  for _, group in ipairs(userConfig.repeatOrder) do
    local src = userConfig.repeatGroups[group]
    local members = merged[group]
    if members == nil then
      members = { map = {}, order = {} }
      merged[group] = members
      table.insert(order, group)
    end
    for _, k in ipairs(src.order) do
      if members.map[k] == nil then
        table.insert(members.order, k)
      end
      members.map[k] = src.map[k]
    end
  end
  local prunedOrder = {}
  for _, group in ipairs(order) do
    local members = merged[group]
    local keptOrder = {}
    for _, k in ipairs(members.order) do
      local b = members.map[k]
      if b.command == 'ignore' then
        members.map[k] = nil
      else
        table.insert(keptOrder, k)
      end
    end
    members.order = keptOrder
    if #keptOrder == 0 then
      merged[group] = nil
    else
      table.insert(prunedOrder, group)
    end
  end
  return merged, prunedOrder
end

local function sameBinding(a, b)
  return a.action == b.action and a.command == b.command and a.keys == b.keys
end

function M.repeatMapFor(binding)
  local groups, order = M.repeatGroups()
  for _, group in ipairs(order) do
    local members = groups[group]
    for _, k in ipairs(members.order) do
      if sameBinding(members.map[k], binding) then
        return members
      end
    end
  end
  return nil
end

function M.whichKeyEnabled()
  if userConfig.whichKey ~= nil then
    return userConfig.whichKey
  end
  if defaultConfig.whichKey ~= nil then
    return defaultConfig.whichKey
  end
  return true
end

function M.whichKeyDelayMs()
  if userConfig.whichKeyDelayMs ~= nil then
    return userConfig.whichKeyDelayMs
  end
  if defaultConfig.whichKeyDelayMs ~= nil then
    return defaultConfig.whichKeyDelayMs
  end
  return DEFAULT_WHICH_KEY_DELAY_MS
end

return M
