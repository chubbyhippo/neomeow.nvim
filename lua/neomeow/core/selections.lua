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
  local st = ctx.st
  local prev = st.lastSelection
  if prev == nil then
    local at = posBefore == nil and active or posBefore
    prev = { type = nil, expand = false, anchor = at, active = at }
  end
  local head = st.selectionHistory[#st.selectionHistory]
  if head == nil or not sameSaved(head, prev) then
    table.insert(st.selectionHistory, prev)
  end
  while #st.selectionHistory > SELECTION_HISTORY_LIMIT do
    table.remove(st.selectionHistory, 1)
  end
  st.lastSelection = { type = type_, expand = expand, anchor = anchor, active = active }
end

function M.select(ctx, type_, markOff, point, expand, push)
  if push == nil then
    push = true
  end
  local port = ctx.port
  local st = ctx.st
  local len = #port:getText()
  local m = text_.clamp(markOff, 0, len)
  local p = text_.clamp(point, 0, len)
  local sels = port:getSelections()
  if push then
    M.recordSelect(ctx, type_, m, p, expand, sels[1].active)
  else
    st.lastSelection = { type = type_, expand = expand, anchor = m, active = p }
  end
  st.selType = type_
  st.selExpand = expand
  sels[1] = { anchor = m, active = p }
  port:setSelections(sels)
  require('neomeow.core.grab').beacon(ctx)
  ctx.ui:showExpandHints(hints.expandHintPositions(ctx))
end

function M.resetSelectionMemory(st)
  st.selectionHistory = {}
  st.lastSelection = nil
end

function M.collapse(ctx)
  local sels = ctx.port:getSelections()
  sels[1] = { anchor = sels[1].active, active = sels[1].active }
  ctx.port:setSelections(sels)
  ctx.st.selType = SelType.NONE
  ctx.st.selExpand = false
end

function M.cancel(ctx)
  M.collapse(ctx)
  M.resetSelectionMemory(ctx.st)
end

local function cancelAll(ctx)
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
  local st = ctx.st
  if M.hasSelection(M.primary(ctx)) then
    local entry = table.remove(st.selectionHistory)
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

local function expand(ctx, n)
  local st = ctx.st
  local text = ctx.port:getText()
  local back = M.backwardP(ctx)
  local caret = M.primary(ctx).active
  local target
  if st.selType == SelType.CHAR then
    target = caret + (back and -n or n)
  elseif st.selType == SelType.WORD or st.selType == SelType.SYMBOL then
    local p = text_.charPred(st.selType == SelType.SYMBOL)
    if back then
      target = text_.Words.prevStart(text, caret, n, p)
    else
      target = text_.Words.nextEnd(text, caret, n, p)
    end
  elseif st.selType == SelType.LINE then
    local ln = text_.lineOfOffset(text, caret)
    if back then
      target = text_.lineStart(text, math.max(ln - n, 0))
    else
      target = text_.lineEnd(text, math.min(ln + n, text_.lineCount(text) - 1))
    end
  elseif st.selType == SelType.FIND or st.selType == SelType.TILL then
    local ch = st.lastFind
    if ch == nil then
      return
    end
    local t = text_.nthCharTarget(text, ch, caret, n, back, st.selType == SelType.TILL)
    if t < 0 then
      return
    end
    target = t
  else
    return
  end
  M.select(ctx, st.selType, M.mark(ctx), target, false)
end

local function expandOrCount(ctx, n)
  local st = ctx.st
  if M.hasSelection(M.primary(ctx)) and EXPANDABLE[st.selType] then
    expand(ctx, n == 0 and EXPAND_ZERO_COUNT or n)
  else
    st.pendingCount = st.pendingCount * 10 + n
  end
end

M.commands = {
  ['meow-reverse'] = reverse,
  ['meow-cancel-selection'] = cancelAll,
  ['meow-pop-selection'] = pop,
}
for n = 0, 9 do
  M.commands['meow-expand-' .. n] = function(ctx)
    expandOrCount(ctx, n)
  end
end

return M
