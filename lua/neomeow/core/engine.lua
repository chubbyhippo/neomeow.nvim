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

local port_ = require('neomeow.core.port')
local State = require('neomeow.core.state')
local MeowMode = State.MeowMode
local Pending = State.Pending
local registry = require('neomeow.core.registry')
local Rc = require('neomeow.core.rc')
local Motions = require('neomeow.core.motions')
local Structures = require('neomeow.core.structures')
local Keypad = require('neomeow.core.keypad')
local Avy = require('neomeow.core.avy')
local Sel = require('neomeow.core.selections')

local M = {}

local KEYPAD_BINDING = { command = 'meow-keypad', recursive = true }

local MAX_REPLAY_DEPTH = 8

M.repeatMap = nil

function M.clearRepeat()
  M.repeatMap = nil
end

function M.enterKeypad(ctx)
  ctx.state.keypadPreviousState = ctx.state.mode
  port_.setMode(ctx, MeowMode.KEYPAD)
  ctx.ui:scheduleWhichKey('keypad', '')
end

function M.runEmacsMotion(ctx, command)
  local cmd = registry.COMMANDS[command]
  if cmd ~= nil then
    cmd(ctx)
  end
  ctx.ui:refresh(ctx.state)
end

local function resolve(ctx, char, motion)
  if char == ' ' then
    return KEYPAD_BINDING
  end
  if ctx.state.noremapDepth == 0 then
    local cfg = Rc.cfg()
    local user = motion and cfg.motion[char] or cfg.normal[char]
    if user ~= nil then
      return user
    end
  end
  local defaults = Rc.defaults()
  return motion and defaults.motion[char] or defaults.normal[char]
end

local function resolvePending(ctx, pending, char)
  if pending == Pending.FIND then
    Motions.findTill(ctx, char, false)
  elseif pending == Pending.TILL then
    Motions.findTill(ctx, char, true)
  else
    Structures.thingSelect(ctx, pending, char)
  end
end

local function startsMultiKeyInput(state, cmd)
  return state.pending ~= nil
    or (state.pendingCount ~= 0 and cmd ~= nil and cmd:sub(1, 12) == 'meow-expand-')
    or (state.negative and cmd == 'meow-negative-argument')
    or cmd == 'meow-keypad'
end

function M.handleChar(ctx, char)
  local state = ctx.state
  if state.mode == MeowMode.INSERT then
    return false
  end
  if state.mode == MeowMode.KEYPAD then
    Keypad.key(ctx, char)
    state.lastCommand = 'keypad'
    ctx.ui:refresh(state)
    return true
  end
  if state.avy ~= nil then
    Avy.key(ctx, char)
    state.lastCommand = 'avy'
    ctx.ui:refresh(state)
    return true
  end

  ctx.ui:hideWhichKey()
  ctx.ui:clearExpandHints()

  local pending = state.pending
  local repeatBinding = nil
  if pending == nil and M.repeatMap ~= nil then
    repeatBinding = M.repeatMap.map[char]
  end
  if pending == nil and repeatBinding == nil then
    M.repeatMap = nil
  end
  local motionish = state.mode == MeowMode.MOTION
  local binding = nil
  if pending == nil then
    binding = repeatBinding
    if binding == nil then
      binding = resolve(ctx, char, motionish)
    end
  end
  local cmd = binding ~= nil and binding.command or nil

  if not state.replaying and cmd ~= 'repeat' then
    if pending == nil and state.pendingCount == 0 and not state.negative then
      state.unit = {}
    end
    table.insert(state.unit, char)
  end

  if pending ~= nil then
    state.pending = nil
    resolvePending(ctx, pending, char)
    state.lastCommand = 'pending'
  elseif binding ~= nil then
    M.runBinding(ctx, binding)
    state.lastCommand = cmd or binding.action or state.lastCommand
  else
    state.lastCommand = nil
  end

  if not state.replaying and cmd ~= 'repeat' and not startsMultiKeyInput(state, cmd) then
    local copy = {}
    for i, key in ipairs(state.unit) do
      copy[i] = key
    end
    state.lastKeys = copy
  end

  ctx.ui:refresh(state)
  return true
end

function M.repeatLast(ctx)
  local state = ctx.state
  local keys = state.lastKeys
  if #keys == 0 then
    return
  end
  state.replaying = true
  local ok, err = pcall(function()
    for _, key in ipairs(keys) do
      M.handleChar(ctx, key)
    end
  end)
  state.replaying = false
  if not ok then
    error(err, 0)
  end
end

local function dispatch(ctx, binding)
  local state = ctx.state
  if binding.command ~= nil then
    local cmd = registry.COMMANDS[binding.command]
    if cmd ~= nil then
      cmd(ctx)
    else
      ctx.ui:hint('Unknown meow command: ' .. binding.command)
    end
    return
  end
  if binding.action ~= nil then
    local ok = pcall(function()
      ctx.ui:runCommand(binding.action)
    end)
    if not ok then
      ctx.ui:hint('Unknown command: ' .. binding.action)
    end
    return
  end
  if binding.keys == nil then
    return
  end
  if state.replayDepth >= MAX_REPLAY_DEPTH then
    ctx.ui:hint('neomeow: mapping recursion is too deep')
    return
  end
  local savedReplaying = state.replaying
  state.replaying = true
  state.replayDepth = state.replayDepth + 1
  if not binding.recursive then
    state.noremapDepth = state.noremapDepth + 1
  end
  local ok, err = pcall(function()
    for i = 1, #binding.keys do
      M.handleChar(ctx, binding.keys:sub(i, i))
    end
  end)
  if not binding.recursive then
    state.noremapDepth = state.noremapDepth - 1
  end
  state.replayDepth = state.replayDepth - 1
  state.replaying = savedReplaying
  if not ok then
    error(err, 0)
  end
end

function M.runBinding(ctx, binding)
  dispatch(ctx, binding)
  local map = Rc.repeatMapFor(binding)
  if map == nil then
    return
  end
  if M.repeatMap == nil then
    ctx.ui:hint('Repeat with ' .. table.concat(map.order, ', '))
  end
  M.repeatMap = map
end

function M.escapeKey(ctx)
  local state = ctx.state
  if state.avy ~= nil then
    Avy.cancel(ctx)
    ctx.ui:refresh(state)
    return true
  end
  local hadTransient = state.pending ~= nil or M.repeatMap ~= nil
  state.pending = nil
  M.repeatMap = nil
  ctx.ui:hideWhichKey()
  ctx.ui:clearExpandHints()
  if state.mode == MeowMode.INSERT then
    port_.setMode(ctx, MeowMode.NORMAL)
    ctx.ui:refresh(state)
    return true
  end
  if state.mode == MeowMode.KEYPAD then
    Keypad.exit(ctx)
    ctx.ui:refresh(state)
    return true
  end
  local sels = ctx.port:getSelections()
  if #sels > 1 or Sel.hasSelection(sels[1]) then
    Sel.cancelAll(ctx)
    ctx.ui:refresh(state)
    return true
  end
  return hadTransient
end

registry.register({
  ['meow-keypad'] = function(ctx)
    M.enterKeypad(ctx)
  end,
  ['repeat'] = function(ctx)
    M.repeatLast(ctx)
  end,
})

return M
