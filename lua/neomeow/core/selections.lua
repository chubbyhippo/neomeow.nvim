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

local text_ = require('neomeow.core.text')
local SelType = require('neomeow.core.state').SelType
local hints = require('neomeow.core.hints')

local M = {}

local SELECTION_HISTORY_LIMIT = 200
local EXPAND_ZERO_COUNT = 10

local EXPANDABLE = {
  [SelType.CHAR] = true,
  [SelType.WORD] = true,
  [SelType.SYMBOL] = true,
  [SelType.LINE] = true,
  [SelType.FIND] = true,
  [SelType.TILL] = true,
}

function M.primary(ctx)
  return ctx.port:getSelections()[1]
end

function M.hasSelection(sel)
  return sel.anchor ~= sel.active
end

function M.selStart(sel)
  return math.min(sel.anchor, sel.active)
end

function M.selEnd(sel)
  return math.max(sel.anchor, sel.active)
end

function M.backwardP(ctx)
  local sel = M.primary(ctx)
  return M.hasSelection(sel) and sel.active < sel.anchor
end

function M.mark(ctx)
  local sel = M.primary(ctx)
  if M.hasSelection(sel) then
    return sel.anchor
  end
  return sel.active
end

local function sameSaved(a, b)
  return a.type == b.type and a.expand == b.expand and a.anchor == b.anchor and a.active == b.active
end

function M.recordSelect(ctx, type_, anchor, active, expand, posBefore)
  local state = ctx.state
  local prev = state.lastSelection
  if prev == nil then
    local at = posBefore == nil and active or posBefore
    prev = { type = nil, expand = false, anchor = at, active = at }
  end
  local head = state.selectionHistory[#state.selectionHistory]
  if head == nil or not sameSaved(head, prev) then
    table.insert(state.selectionHistory, prev)
  end
  while #state.selectionHistory > SELECTION_HISTORY_LIMIT do
    table.remove(state.selectionHistory, 1)
  end
  state.lastSelection = { type = type_, expand = expand, anchor = anchor, active = active }
end

function M.select(ctx, type_, markOff, point, expand, push)
  if push == nil then
    push = true
  end
  local port = ctx.port
  local state = ctx.state
  local len = #port:getText()
  local anchor = text_.clamp(markOff, 0, len)
  local active = text_.clamp(point, 0, len)
  local sels = port:getSelections()
  if push then
    M.recordSelect(ctx, type_, anchor, active, expand, sels[1].active)
  else
    state.lastSelection = { type = type_, expand = expand, anchor = anchor, active = active }
  end
  state.selType = type_
  state.selExpand = expand
  sels[1] = { anchor = anchor, active = active }
  port:setSelections(sels)
  require('neomeow.core.grab').beacon(ctx)
  ctx.ui:showExpandHints(hints.expandHintPositions(ctx))
end

function M.resetSelectionMemory(state)
  state.selectionHistory = {}
  state.lastSelection = nil
end

function M.collapse(ctx)
  local sels = ctx.port:getSelections()
  sels[1] = { anchor = sels[1].active, active = sels[1].active }
  ctx.port:setSelections(sels)
  ctx.state.selType = SelType.NONE
  ctx.state.selExpand = false
end

function M.cancel(ctx)
  M.collapse(ctx)
  M.resetSelectionMemory(ctx.state)
end

function M.cancelAll(ctx)
  local sels = ctx.port:getSelections()
  if #sels > 1 then
    ctx.port:setSelections({ sels[1] })
  end
  M.cancel(ctx)
end

local function reverse(ctx)
  local sel = M.primary(ctx)
  if not M.hasSelection(sel) then
    return
  end
  local sels = ctx.port:getSelections()
  sels[1] = { anchor = sel.active, active = sel.anchor }
  ctx.port:setSelections(sels)
end

local function pop(ctx)
  local state = ctx.state
  if M.hasSelection(M.primary(ctx)) then
    local entry = table.remove(state.selectionHistory)
    if entry == nil then
      return
    end
    if entry.type == nil then
      local sels = ctx.port:getSelections()
      sels[1] = { anchor = entry.active, active = entry.active }
      ctx.port:setSelections(sels)
      M.cancel(ctx)
      ctx.ui:hint('No previous selection')
    else
      M.select(ctx, entry.type, entry.anchor, entry.active, entry.expand, false)
    end
  elseif not require('neomeow.core.grab').pop(ctx) then
    ctx.ui:hint('No previous selection')
  end
end

local function expand(ctx, count)
  local state = ctx.state
  local text = ctx.port:getText()
  local back = M.backwardP(ctx)
  local caret = M.primary(ctx).active
  local target
  if state.selType == SelType.CHAR then
    target = caret + (back and -count or count)
  elseif state.selType == SelType.WORD or state.selType == SelType.SYMBOL then
    local isWord = text_.charPred(state.selType == SelType.SYMBOL)
    if back then
      target = text_.Words.prevStart(text, caret, count, isWord)
    else
      target = text_.Words.nextEnd(text, caret, count, isWord)
    end
  elseif state.selType == SelType.LINE then
    local caretLine = text_.lineOfOffset(text, caret)
    if back then
      target = text_.lineStart(text, math.max(caretLine - count, 0))
    else
      target = text_.lineEnd(text, math.min(caretLine + count, text_.lineCount(text) - 1))
    end
  elseif state.selType == SelType.FIND or state.selType == SelType.TILL then
    local char = state.lastFind
    if char == nil then
      return
    end
    local found = text_.nthCharTarget(text, char, caret, count, back, state.selType == SelType.TILL)
    if found < 0 then
      return
    end
    target = found
  else
    return
  end
  M.select(ctx, state.selType, M.mark(ctx), target, false)
end

local function expandOrCount(ctx, digit)
  local state = ctx.state
  if M.hasSelection(M.primary(ctx)) and EXPANDABLE[state.selType] then
    expand(ctx, digit == 0 and EXPAND_ZERO_COUNT or digit)
  else
    state.pendingCount = state.pendingCount * 10 + digit
  end
end

M.commands = {
  ['meow-reverse'] = reverse,
  ['meow-cancel-selection'] = M.cancelAll,
  ['meow-pop-selection'] = pop,
}
for digit = 0, 9 do
  M.commands['meow-expand-' .. digit] = function(ctx)
    expandOrCount(ctx, digit)
  end
end

return M
