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
local state = require('neomeow.core.state')
local MeowMode = state.MeowMode
local Pending = state.Pending
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
  ctx.st.keypadPreviousState = ctx.st.mode
  port_.setMode(ctx, MeowMode.KEYPAD)
  ctx.ui:scheduleWhichKey('keypad', '')
end

function M.runEmacsMotion(ctx, command)
  local cmd = registry.COMMANDS[command]
  if cmd ~= nil then
    cmd(ctx)
  end
  ctx.ui:refresh(ctx.st)
end

local function resolve(ctx, c, motion)
  if c == ' ' then
    return KEYPAD_BINDING
  end
  if ctx.st.noremapDepth == 0 then
    local cfg = Rc.cfg()
    local user = motion and cfg.motion[c] or cfg.normal[c]
    if user ~= nil then
      return user
    end
  end
  local d = Rc.defaults()
  local def = motion and d.motion[c] or d.normal[c]
  return def
end

local function resolvePending(ctx, p, c)
  if p == Pending.FIND then
    Motions.findTill(ctx, c, false)
  elseif p == Pending.TILL then
    Motions.findTill(ctx, c, true)
  else
    Structures.thingSelect(ctx, p, c)
  end
end

local function startsMultiKeyInput(st, cmd)
  return st.pending ~= nil
    or (st.pendingCount ~= 0 and cmd ~= nil and cmd:sub(1, 12) == 'meow-expand-')
    or (st.negative and cmd == 'meow-negative-argument')
    or cmd == 'meow-keypad'
end

function M.handleChar(ctx, c)
  local st = ctx.st
  if st.mode == MeowMode.INSERT then
    return false
  end
  if st.mode == MeowMode.KEYPAD then
    Keypad.key(ctx, c)
    st.lastCommand = 'keypad'
    ctx.ui:refresh(st)
    return true
  end
  if st.avy ~= nil then
    Avy.key(ctx, c)
    st.lastCommand = 'avy'
    ctx.ui:refresh(st)
    return true
  end

  ctx.ui:hideWhichKey()
  ctx.ui:clearExpandHints()

  local pend = st.pending
  local repeatBinding = nil
  if pend == nil and M.repeatMap ~= nil then
    repeatBinding = M.repeatMap.map[c]
  end
  if pend == nil and repeatBinding == nil then
    M.repeatMap = nil
  end
  local motionish = st.mode == MeowMode.MOTION
  local binding = nil
  if pend == nil then
    binding = repeatBinding
    if binding == nil then
      binding = resolve(ctx, c, motionish)
    end
  end
  local cmd = binding ~= nil and binding.command or nil

  if not st.replaying and cmd ~= 'repeat' then
    if pend == nil and st.pendingCount == 0 and not st.negative then
      st.unit = {}
    end
    table.insert(st.unit, c)
  end

  if pend ~= nil then
    st.pending = nil
    resolvePending(ctx, pend, c)
    st.lastCommand = 'pending'
  elseif binding ~= nil then
    M.runBinding(ctx, binding)
    st.lastCommand = cmd or binding.action or st.lastCommand
  else
    st.lastCommand = nil
  end

  if not st.replaying and cmd ~= 'repeat' and not startsMultiKeyInput(st, cmd) then
    local copy = {}
    for i, k in ipairs(st.unit) do
      copy[i] = k
    end
    st.lastKeys = copy
  end

  ctx.ui:refresh(st)
  return true
end

function M.repeatLast(ctx)
  local st = ctx.st
  local keys = st.lastKeys
  if #keys == 0 then
    return
  end
  st.replaying = true
  local ok, err = pcall(function()
    for _, k in ipairs(keys) do
      M.handleChar(ctx, k)
    end
  end)
  st.replaying = false
  if not ok then
    error(err, 0)
  end
end

local function dispatch(ctx, b)
  local st = ctx.st
  if b.command ~= nil then
    local cmd = registry.COMMANDS[b.command]
    if cmd ~= nil then
      cmd(ctx)
    else
      ctx.ui:hint('Unknown meow command: ' .. b.command)
    end
    return
  end
  if b.action ~= nil then
    local ok = pcall(function()
      ctx.ui:runCommand(b.action)
    end)
    if not ok then
      ctx.ui:hint('Unknown command: ' .. b.action)
    end
    return
  end
  if b.keys == nil then
    return
  end
  if st.replayDepth >= MAX_REPLAY_DEPTH then
    ctx.ui:hint('neomeow: mapping recursion is too deep')
    return
  end
  local savedReplaying = st.replaying
  st.replaying = true
  st.replayDepth = st.replayDepth + 1
  if not b.recursive then
    st.noremapDepth = st.noremapDepth + 1
  end
  local ok, err = pcall(function()
    for i = 1, #b.keys do
      M.handleChar(ctx, b.keys:sub(i, i))
    end
  end)
  if not b.recursive then
    st.noremapDepth = st.noremapDepth - 1
  end
  st.replayDepth = st.replayDepth - 1
  st.replaying = savedReplaying
  if not ok then
    error(err, 0)
  end
end

function M.runBinding(ctx, b)
  dispatch(ctx, b)
  local map = Rc.repeatMapFor(b)
  if map == nil then
    return
  end
  if M.repeatMap == nil then
    ctx.ui:hint('Repeat with ' .. table.concat(map.order, ', '))
  end
  M.repeatMap = map
end

function M.escapeKey(ctx)
  local st = ctx.st
  if st.avy ~= nil then
    Avy.cancel(ctx)
    ctx.ui:refresh(st)
    return true
  end
  st.pending = nil
  M.repeatMap = nil
  ctx.ui:hideWhichKey()
  ctx.ui:clearExpandHints()
  if st.mode == MeowMode.INSERT then
    port_.setMode(ctx, MeowMode.NORMAL)
    ctx.ui:refresh(st)
    return true
  end
  if st.mode == MeowMode.KEYPAD then
    Keypad.exit(ctx)
    ctx.ui:refresh(st)
    return true
  end
  local sels = ctx.port:getSelections()
  if #sels > 1 or Sel.hasSelection(sels[1]) then
    Sel.cancelAll(ctx)
    ctx.ui:refresh(st)
    return true
  end
  return false
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
