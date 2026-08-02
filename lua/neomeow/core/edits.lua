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
local State = require('neomeow.core.state')
local MeowMode = State.MeowMode
local SelType = State.SelType
local port_ = require('neomeow.core.port')
local Sel = require('neomeow.core.selections')
local Grab = require('neomeow.core.grab')

local M = {}

local function allowModify(ctx)
  return ctx.port:isWritable()
end

function M.blockedReadOnly(ctx)
  if allowModify(ctx) then
    return false
  end
  ctx.ui:hint('Buffer is read-only')
  return true
end

local function editCarets(ctx, compute)
  local sels = ctx.port:getSelections()
  local order = {}
  for index, sel in ipairs(sels) do
    table.insert(order, { sel = sel, index = index, selStart = Sel.selStart(sel) })
  end
  table.sort(order, function(a, b)
    if a.selStart ~= b.selStart then
      return a.selStart > b.selStart
    end
    return a.index < b.index
  end)
  local edits = {}
  local results = {}
  for _, item in ipairs(order) do
    local selEnd = Sel.selEnd(item.sel)
    local result = compute(item.sel, item.selStart, selEnd)
    if result.edit ~= nil then
      table.insert(edits, result.edit)
    end
    results[item.index] = result
  end
  local newSels = {}
  local delta = 0
  for i = #order, 1, -1 do
    local item = order[i]
    local result = results[item.index]
    newSels[item.index] = { anchor = result.sel.anchor + delta, active = result.sel.active + delta }
    if result.edit ~= nil then
      delta = delta + #result.edit.text - (result.edit.stop - result.edit.start)
    end
  end
  Grab.adjustForEdits(ctx.state, edits)
  if #edits > 0 then
    ctx.port:edit(edits)
  end
  ctx.port:setSelections(newSels)
end

local function deleteSelectionOrCharForward(text, selStart, selEnd)
  if selStart ~= selEnd then
    return { edit = { start = selStart, stop = selEnd, text = '' }, sel = { anchor = selStart, active = selStart } }
  end
  if selStart < #text then
    return {
      edit = { start = selStart, stop = selStart + 1, text = '' },
      sel = { anchor = selStart, active = selStart },
    }
  end
  return { edit = nil, sel = { anchor = selStart, active = selStart } }
end

local function insert(ctx)
  local moved = {}
  for i, sel in ipairs(ctx.port:getSelections()) do
    local offset = Sel.selStart(sel)
    moved[i] = { anchor = offset, active = offset }
  end
  ctx.port:setSelections(moved)
  ctx.state.selType = SelType.NONE
  Sel.resetSelectionMemory(ctx.state)
  port_.setMode(ctx, MeowMode.INSERT)
end

local function append(ctx)
  local moved = {}
  for i, sel in ipairs(ctx.port:getSelections()) do
    local offset = Sel.selEnd(sel)
    moved[i] = { anchor = offset, active = offset }
  end
  ctx.port:setSelections(moved)
  ctx.state.selType = SelType.NONE
  Sel.resetSelectionMemory(ctx.state)
  port_.setMode(ctx, MeowMode.INSERT)
end

local function openBelow(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local text = ctx.port:getText()
  local eol = text_.lineEnd(text, text_.lineOfOffset(text, Sel.primary(ctx).active))
  local edits = { { start = eol, stop = eol, text = '\n' } }
  Grab.adjustForEdits(ctx.state, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = eol + 1, active = eol + 1 } })
  port_.setMode(ctx, MeowMode.INSERT)
end

local function openLine(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local at = Sel.primary(ctx).active
  local edits = { { start = at, stop = at, text = '\n' } }
  Grab.adjustForEdits(ctx.state, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = at, active = at } })
end

local function horizontalSpace(ctx, replacement)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local text = ctx.port:getText()
  local at = Sel.primary(ctx).active
  local from = at
  while from > 0 and text_.isBlank(text:sub(from, from)) do
    from = from - 1
  end
  local to = at
  while to < #text and text_.isBlank(text:sub(to + 1, to + 1)) do
    to = to + 1
  end
  if from == to and replacement == '' then
    return
  end
  local edits = { { start = from, stop = to, text = replacement } }
  Grab.adjustForEdits(ctx.state, edits)
  ctx.port:edit(edits)
  local caret = from + #replacement
  ctx.port:setSelections({ { anchor = caret, active = caret } })
end

local function openAbove(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local text = ctx.port:getText()
  local lineStartOffset = text_.lineStart(text, text_.lineOfOffset(text, Sel.primary(ctx).active))
  local edits = { { start = lineStartOffset, stop = lineStartOffset, text = '\n' } }
  Grab.adjustForEdits(ctx.state, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = lineStartOffset, active = lineStartOffset } })
  port_.setMode(ctx, MeowMode.INSERT)
end

local function change(ctx)
  if not allowModify(ctx) then
    return
  end
  local text = ctx.port:getText()
  local prim = Sel.primary(ctx)
  if not Sel.hasSelection(prim) and prim.active >= #text then
    return
  end
  editCarets(ctx, function(_sel, selStart, selEnd)
    return deleteSelectionOrCharForward(text, selStart, selEnd)
  end)
  ctx.state.selType = SelType.NONE
  port_.setMode(ctx, MeowMode.INSERT)
end

local function del(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  local text = ctx.port:getText()
  editCarets(ctx, function(_sel, selStart, selEnd)
    return deleteSelectionOrCharForward(text, selStart, selEnd)
  end)
  ctx.state.selType = SelType.NONE
end

local function backwardDelete(ctx)
  if not allowModify(ctx) then
    return
  end
  editCarets(ctx, function(_sel, selStart, selEnd)
    if selStart ~= selEnd then
      return { edit = { start = selStart, stop = selEnd, text = '' }, sel = { anchor = selStart, active = selStart } }
    end
    if selStart > 0 then
      return {
        edit = { start = selStart - 1, stop = selStart, text = '' },
        sel = { anchor = selStart - 1, active = selStart - 1 },
      }
    end
    return { edit = nil, sel = { anchor = selStart, active = selStart } }
  end)
  ctx.state.selType = SelType.NONE
end

local function killRange(ctx, sel, text)
  local selStart = Sel.selStart(sel)
  local selEnd = Sel.selEnd(sel)
  if ctx.state.selType == SelType.LINE and sel.active >= sel.anchor and selEnd < #text then
    if text_.charAt(text, selEnd) == '\r' then
      selEnd = selEnd + 1
    end
    if selEnd < #text and text_.charAt(text, selEnd) == '\n' then
      selEnd = selEnd + 1
    end
  end
  return { selStart = selStart, selEnd = selEnd }
end

local function regionsInOrder(sels)
  local regions = {}
  for _, sel in ipairs(sels) do
    if sel.anchor ~= sel.active then
      table.insert(regions, sel)
    end
  end
  table.sort(regions, function(a, b)
    return Sel.selStart(a) < Sel.selStart(b)
  end)
  return regions
end

local function joinedKillText(ctx, text, regions)
  local parts = {}
  for _, sel in ipairs(regions) do
    local killed = killRange(ctx, sel, text)
    table.insert(parts, text_.slice(text, killed.selStart, killed.selEnd))
  end
  return table.concat(parts, '\n')
end

local function joinKill(ctx)
  local text = ctx.port:getText()
  local prim = Sel.primary(ctx)
  local selStart = Sel.selStart(prim)
  local selEnd = Sel.selEnd(prim)
  local before = selStart > 0 and text_.charAt(text, selStart - 1) or '\n'
  local after = selEnd < #text and text_.charAt(text, selEnd) or '\n'
  local space = before ~= '\n'
    and after ~= '\n'
    and before:match('^%s$') == nil
    and after:match('^%s$') == nil
    and (')]}.,;:'):find(after, 1, true) == nil
    and ('([{'):find(before, 1, true) == nil
  local edits = { { start = selStart, stop = selEnd, text = space and ' ' or '' } }
  Grab.adjustForEdits(ctx.state, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = selStart, active = selStart } })
  ctx.state.selType = SelType.NONE
  ctx.state.selExpand = false
end

local function kill(ctx)
  if not allowModify(ctx) then
    return
  end
  local state = ctx.state
  local text = ctx.port:getText()
  local prim = Sel.primary(ctx)
  if state.selType == SelType.JOIN and Sel.hasSelection(prim) then
    joinKill(ctx)
    return
  end
  if Sel.hasSelection(prim) then
    ctx.clipboard:write(joinedKillText(ctx, text, regionsInOrder(ctx.port:getSelections())))
    editCarets(ctx, function(sel, selStart, selEnd)
      if selStart == selEnd then
        return { edit = nil, sel = sel }
      end
      local killed = killRange(ctx, sel, text)
      return {
        edit = { start = killed.selStart, stop = killed.selEnd, text = '' },
        sel = { anchor = killed.selStart, active = killed.selStart },
      }
    end)
    state.selType = SelType.NONE
    return
  end
  if #text == 0 then
    return
  end
  local caret = prim.active
  local caretLine = text_.lineOfOffset(text, caret)
  local eol = text_.lineEnd(text, caretLine)
  local stop = caret == eol and text_.lineStart(text, caretLine + 1) or eol
  if stop > caret then
    ctx.clipboard:write(text_.slice(text, caret, stop))
    local edits = { { start = caret, stop = stop, text = '' } }
    Grab.adjustForEdits(state, edits)
    ctx.port:edit(edits)
    ctx.port:setSelections({ { anchor = caret, active = caret } })
  end
end

local function save(ctx)
  local text = ctx.port:getText()
  local sels = ctx.port:getSelections()
  local withSel = regionsInOrder(sels)
  if #withSel == 0 then
    return
  end
  ctx.clipboard:write(joinedKillText(ctx, text, withSel))
  local moved = {}
  for i, sel in ipairs(sels) do
    if sel.anchor == sel.active then
      moved[i] = sel
    else
      local killed = killRange(ctx, sel, text)
      local caret = sel.active >= sel.anchor and killed.selEnd or killed.selStart
      moved[i] = { anchor = caret, active = caret }
    end
  end
  ctx.port:setSelections(moved)
  ctx.state.selType = SelType.NONE
  ctx.state.selExpand = false
end

local function yank(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  local clip = ctx.clipboard:read()
  if clip == nil or clip == '' then
    return
  end
  editCarets(ctx, function(sel)
    return {
      edit = { start = sel.active, stop = sel.active, text = clip },
      sel = { anchor = sel.active + #clip, active = sel.active + #clip },
    }
  end)
end

local function replace(ctx)
  if not allowModify(ctx) then
    return
  end
  if not Sel.hasSelection(Sel.primary(ctx)) then
    return
  end
  local raw = ctx.clipboard:read()
  if raw == nil then
    return
  end
  local clip = raw:gsub('\n+$', '')
  editCarets(ctx, function(sel, selStart, selEnd)
    if selStart == selEnd then
      return { edit = nil, sel = sel }
    end
    return {
      edit = { start = selStart, stop = selEnd, text = clip },
      sel = { anchor = selStart + #clip, active = selStart + #clip },
    }
  end)
  ctx.state.selType = SelType.NONE
end

local function capitalizedWords(slice)
  local isWord = text_.charPred(false)
  local out = {}
  local inWord = false
  for i = 1, #slice do
    local char = slice:sub(i, i)
    if isWord(char) then
      table.insert(out, inWord and char:lower() or char:upper())
      inWord = true
    else
      table.insert(out, char)
      inWord = false
    end
  end
  return table.concat(out)
end

local function casified(slice, op)
  if op == 'upcase' then
    return slice:upper()
  end
  if op == 'downcase' then
    return slice:lower()
  end
  return capitalizedWords(slice)
end

local function caseWord(ctx, op)
  if M.blockedReadOnly(ctx) then
    return
  end
  local count = ctx.state:takeCount(1)
  if count == 0 then
    return
  end
  local hadSelection = Sel.hasSelection(Sel.primary(ctx))
  local text = ctx.port:getText()
  local isWord = text_.charPred(false)
  editCarets(ctx, function(sel)
    local from = sel.active
    local target
    if count > 0 then
      target = text_.Words.nextEnd(text, from, count, isWord)
    else
      target = text_.Words.prevStart(text, from, -count, isWord)
    end
    local startOffset = math.min(from, target)
    local endOffset = math.max(from, target)
    if startOffset == endOffset then
      return { edit = nil, sel = sel }
    end
    local caret = count > 0 and endOffset or from
    return {
      edit = {
        start = startOffset,
        stop = endOffset,
        text = casified(text_.slice(text, startOffset, endOffset), op),
      },
      sel = { anchor = caret, active = caret },
    }
  end)
  if hadSelection then
    Sel.collapse(ctx)
  end
end

local function killWord(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  local count = ctx.state:takeCount(1)
  if count == 0 then
    return
  end
  local text = ctx.port:getText()
  local isWord = text_.charPred(false)
  local function rangeAt(from)
    local target
    if count > 0 then
      target = text_.Words.nextEnd(text, from, count, isWord)
    else
      target = text_.Words.prevStart(text, from, -count, isWord)
    end
    return { startOffset = math.min(from, target), endOffset = math.max(from, target) }
  end
  local killed = {}
  for _, sel in ipairs(ctx.port:getSelections()) do
    local range = rangeAt(sel.active)
    if range.startOffset ~= range.endOffset then
      table.insert(killed, range)
    end
  end
  table.sort(killed, function(a, b)
    return a.startOffset < b.startOffset
  end)
  if #killed == 0 then
    return
  end
  local parts = {}
  for _, range in ipairs(killed) do
    table.insert(parts, text_.slice(text, range.startOffset, range.endOffset))
  end
  ctx.clipboard:write(table.concat(parts, '\n'))
  editCarets(ctx, function(sel)
    local range = rangeAt(sel.active)
    if range.startOffset == range.endOffset then
      return { edit = nil, sel = { anchor = sel.active, active = sel.active } }
    end
    return {
      edit = { start = range.startOffset, stop = range.endOffset, text = '' },
      sel = { anchor = range.startOffset, active = range.startOffset },
    }
  end)
  ctx.state.selType = SelType.NONE
  ctx.state.selExpand = false
end

local function undo(ctx)
  if Sel.hasSelection(Sel.primary(ctx)) then
    Sel.cancel(ctx)
  end
  ctx.port:undo()
end

local function undoInSelection(ctx)
  if Sel.hasSelection(Sel.primary(ctx)) then
    ctx.port:undo()
  end
end

M.commands = {
  ['meow-insert'] = insert,
  ['meow-append'] = append,
  ['meow-open-above'] = openAbove,
  ['meow-open-below'] = openBelow,
  ['meow-change'] = change,
  ['meow-delete'] = del,
  ['meow-backward-delete'] = backwardDelete,
  ['meow-kill'] = kill,
  ['meow-save'] = save,
  ['meow-yank'] = yank,
  ['meow-replace'] = replace,
  ['meow-undo'] = undo,
  ['meow-undo-in-selection'] = undoInSelection,
  ['upcase-word'] = function(ctx)
    caseWord(ctx, 'upcase')
  end,
  ['downcase-word'] = function(ctx)
    caseWord(ctx, 'downcase')
  end,
  ['capitalize-word'] = function(ctx)
    caseWord(ctx, 'capitalize')
  end,
  ['kill-word'] = killWord,
  ['open-line'] = openLine,
  ['delete-horizontal-space'] = function(ctx)
    horizontalSpace(ctx, '')
  end,
  ['just-one-space'] = function(ctx)
    horizontalSpace(ctx, ' ')
  end,
}

return M
