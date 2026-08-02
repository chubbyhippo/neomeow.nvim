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

local DEFAULT_OVERLAY_COLOR = '#2ecc71'
local DEFAULT_OVERLAY_TEXT_COLOR = '#ffffff'
local DEFAULT_EXPAND_HINT_COLOR = '#2b5db2'
local DEFAULT_GRAB_COLOR = nil

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

function M.setForTest(config)
  userConfig = config
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
  for _, key in ipairs(defOrder) do
    if map[key] == nil then
      table.insert(order, key)
    end
    map[key] = defMap[key]
  end
  for _, key in ipairs(userOrder) do
    if map[key] == nil then
      table.insert(order, key)
    end
    map[key] = userMap[key]
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

local function prunedIgnores(map, order)
  local kept = {}
  for _, key in ipairs(order) do
    if map[key].command == 'ignore' then
      map[key] = nil
    else
      table.insert(kept, key)
    end
  end
  return map, kept
end

function M.chordBindings()
  return prunedIgnores(
    mergedOrdered(defaultConfig.chords, defaultConfig.chordOrder, userConfig.chords, userConfig.chordOrder)
  )
end

function M.resizeBindings()
  return prunedIgnores(
    mergedOrdered(defaultConfig.resizes, defaultConfig.resizeOrder, userConfig.resizes, userConfig.resizeOrder)
  )
end

function M.repeatGroups()
  local merged = {}
  local order = {}
  for _, group in ipairs(defaultConfig.repeatOrder) do
    local src = defaultConfig.repeatGroups[group]
    local members = { map = {}, order = {} }
    for _, key in ipairs(src.order) do
      members.map[key] = src.map[key]
      table.insert(members.order, key)
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
    for _, key in ipairs(src.order) do
      if members.map[key] == nil then
        table.insert(members.order, key)
      end
      members.map[key] = src.map[key]
    end
  end
  local prunedOrder = {}
  for _, group in ipairs(order) do
    local members = merged[group]
    local _, keptOrder = prunedIgnores(members.map, members.order)
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
    for _, key in ipairs(members.order) do
      if sameBinding(members.map[key], binding) then
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

local function resolveColor(field, fallback)
  if userConfig[field] ~= nil then
    return userConfig[field]
  end
  if defaultConfig[field] ~= nil then
    return defaultConfig[field]
  end
  return fallback
end

function M.overlayColor()
  return resolveColor('overlayColor', DEFAULT_OVERLAY_COLOR)
end

function M.overlayTextColor()
  return resolveColor('overlayTextColor', DEFAULT_OVERLAY_TEXT_COLOR)
end

function M.expandHintColor()
  return resolveColor('expandHintColor', DEFAULT_EXPAND_HINT_COLOR)
end

function M.grabColor()
  return resolveColor('grabColor', DEFAULT_GRAB_COLOR)
end

return M
