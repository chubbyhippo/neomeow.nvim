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
local SelType = State.SelType
local Pending = State.Pending
local Sel = require('neomeow.core.selections')
local Search = require('neomeow.core.search')

local M = {}

local function lineStartTarget(text, offset)
  return text_.lineStart(text, text_.lineOfOffset(text, offset))
end

local function lineEndTarget(text, offset)
  return text_.lineEnd(text, text_.lineOfOffset(text, offset))
end

local function indentationTarget(text, offset)
  local line = text_.lineOfOffset(text, offset)
  local stop = text_.lineEnd(text, line)
  local at = text_.lineStart(text, line)
  while at < stop and text_.isBlank(text:sub(at + 1, at + 1)) do
    at = at + 1
  end
  return at
end

local function wordType(symbol)
  if symbol then
    return SelType.SYMBOL
  end
  return SelType.WORD
end

local VERTICAL = {
  ['meow-next'] = true,
  ['meow-prev'] = true,
  ['meow-next-expand'] = true,
  ['meow-prev-expand'] = true,
  ['next-line'] = true,
  ['previous-line'] = true,
}

local function charSelActive(ctx)
  return ctx.state.selType == SelType.CHAR and Sel.hasSelection(Sel.primary(ctx))
end

local function movedChar(len, sel, dx, extend)
  local active = text_.clamp(sel.active + dx, 0, len)
  return { anchor = extend and sel.anchor or active, active = active }
end

local function movedLine(text, sel, dy, extend, goal)
  local caretLine = text_.lineOfOffset(text, sel.active)
  local target = caretLine + dy
  local active
  if target < 0 then
    active = 0
  elseif target > text_.lineCount(text) - 1 then
    active = #text
  else
    local col
    if goal ~= nil then
      col = goal
    else
      col = sel.active - text_.lineStart(text, caretLine)
    end
    local lineStartOffset = text_.lineStart(text, target)
    active = lineStartOffset + math.min(col, text_.lineEnd(text, target) - lineStartOffset)
  end
  return { anchor = extend and sel.anchor or active, active = active }
end

local function goalColumn(ctx)
  local state = ctx.state
  if state.goalColumn == nil or state.lastCommand == nil or not VERTICAL[state.lastCommand] then
    local text = ctx.port:getText()
    local caret = Sel.primary(ctx).active
    state.goalColumn = caret - text_.lineStart(text, text_.lineOfOffset(text, caret))
  end
  return state.goalColumn
end

local function moveChar(ctx, dx)
  local extend = charSelActive(ctx)
  if not extend and Sel.hasSelection(Sel.primary(ctx)) then
    Sel.cancel(ctx)
  end
  local len = #ctx.port:getText()
  local moved = {}
  for i, sel in ipairs(ctx.port:getSelections()) do
    moved[i] = movedChar(len, sel, dx, extend)
  end
  ctx.port:setSelections(moved)
end

local function moveLine(ctx, dy)
  local extend = charSelActive(ctx)
  if not extend then
    Sel.cancel(ctx)
  end
  local goal = goalColumn(ctx)
  local text = ctx.port:getText()
  local moved = {}
  for i, sel in ipairs(ctx.port:getSelections()) do
    moved[i] = movedLine(text, sel, dy, extend, i == 1 and goal or nil)
  end
  ctx.port:setSelections(moved)
end

local function moveExpand(ctx, dx, dy)
  local text = ctx.port:getText()
  local goal = nil
  if dy ~= 0 then
    goal = goalColumn(ctx)
  end
  local sels = ctx.port:getSelections()
  local before = sels[1].active
  local moved = {}
  for i, sel in ipairs(sels) do
    if dy == 0 then
      moved[i] = movedChar(#text, sel, dx, true)
    else
      moved[i] = movedLine(text, sel, dy, true, i == 1 and goal or nil)
    end
  end
  ctx.port:setSelections(moved)
  Sel.recordSelect(ctx, SelType.CHAR, moved[1].anchor, moved[1].active, true, before)
  ctx.state.selType = SelType.CHAR
  ctx.state.selExpand = true
  require('neomeow.core.grab').beacon(ctx)
end

local function charOrExpand(ctx, dx)
  if Sel.hasSelection(Sel.primary(ctx)) then
    moveExpand(ctx, dx, 0)
  else
    moveChar(ctx, dx)
  end
end

local function lineOrExpand(ctx, dy)
  if Sel.hasSelection(Sel.primary(ctx)) then
    moveExpand(ctx, 0, dy)
  else
    moveLine(ctx, dy)
  end
end

local function moveToOrExpand(ctx, type_, target)
  local text = ctx.port:getText()
  local extend = Sel.hasSelection(Sel.primary(ctx))
  local before = Sel.primary(ctx).active
  local moved = {}
  for i, sel in ipairs(ctx.port:getSelections()) do
    local active = text_.clamp(target(text, sel.active), 0, #text)
    moved[i] = { anchor = extend and sel.anchor or active, active = active }
  end
  ctx.port:setSelections(moved)
  if extend then
    Sel.recordSelect(ctx, type_, moved[1].anchor, moved[1].active, true, before)
    ctx.state.selType = type_
    ctx.state.selExpand = true
    require('neomeow.core.grab').beacon(ctx)
  end
end

local function wordOrExpand(ctx, count)
  local isWord = text_.charPred(false)
  moveToOrExpand(ctx, SelType.WORD, function(text, offset)
    if count >= 0 then
      return text_.Words.nextEnd(text, offset, count, isWord)
    end
    return text_.Words.prevStart(text, offset, -count, isWord)
  end)
end

local function sentenceOrExpand(ctx, count)
  moveToOrExpand(ctx, SelType.CHAR, function(text, offset)
    if count >= 0 then
      return text_.nextSentenceEnd(text, offset, count)
    end
    return text_.prevSentenceStart(text, offset, -count)
  end)
end

local function paragraphOrExpand(ctx, count)
  moveToOrExpand(ctx, SelType.CHAR, function(text, offset)
    if count >= 0 then
      return text_.nextParagraphEnd(text, offset, count)
    end
    return text_.prevParagraphStart(text, offset, -count)
  end)
end

local function nextLineStart(text, offset)
  if #text == 0 then
    return 0
  end
  local line = text_.lineOfOffset(text, text_.clamp(offset, 0, #text))
  if line >= text_.lineCount(text) - 1 then
    return #text
  end
  return text_.lineStart(text, line + 1)
end

local function bufferBoundary(ctx, top)
  local counted = ctx.state.pendingCount ~= 0 or ctx.state.negative
  local count = ctx.state:takeCount(1)
  moveToOrExpand(ctx, SelType.CHAR, function(text)
    local len = #text
    if not counted then
      if top then
        return 0
      end
      return len
    end
    local fraction = len * count / 10
    local tenth = fraction >= 0 and math.floor(fraction) or math.ceil(fraction)
    local raw = text_.clamp(top and tenth or len - tenth, 0, len)
    return nextLineStart(text, raw)
  end)
end

local function wordMotion(ctx, symbol, count)
  if count == 0 then
    return
  end
  local text = ctx.port:getText()
  local type_ = wordType(symbol)
  local sel = Sel.primary(ctx)
  local selStart = Sel.selStart(sel)
  local selEnd = Sel.selEnd(sel)
  if not (Sel.hasSelection(sel) and ctx.state.selType == type_) then
    Sel.cancel(ctx)
  end
  local extend = ctx.state.selExpand and ctx.state.selType == type_ and Sel.hasSelection(sel)
  local from
  if extend then
    from = count < 0 and selStart or selEnd
  else
    from = sel.active
  end
  local target
  if count > 0 then
    target = text_.Words.nextEnd(text, from, count, text_.charPred(symbol))
  else
    target = text_.Words.prevStart(text, from, -count, text_.charPred(symbol))
  end
  if target == from then
    return
  end
  local anchor
  if extend then
    anchor = count < 0 and selEnd or selStart
  else
    anchor = text_.Words.fixSelectionMark(text, target, from, text_.charPred(symbol))
  end
  Sel.select(ctx, type_, anchor, target, extend)
end

local SYMBOL_BOUNDARY = '\\%([0-9A-Za-z_$]\\)'

local function markWord(ctx, symbol)
  local backward = ctx.state:takeCount(1) < 0
  local text = ctx.port:getText()
  local bounds = text_.Words.boundsAt(text, Sel.primary(ctx).active, text_.charPred(symbol))
  if bounds == nil then
    ctx.ui:hint('No word here')
    return
  end
  local wordStart = bounds[1]
  local wordEnd = bounds[2]
  if backward then
    Sel.select(ctx, wordType(symbol), wordEnd, wordStart, true)
  else
    Sel.select(ctx, wordType(symbol), wordStart, wordEnd, true)
  end
  local quoted = text_.regexQuote(text_.slice(text, wordStart, wordEnd))
  if symbol then
    Search.push(ctx.state, SYMBOL_BOUNDARY .. '\\@<!' .. quoted .. SYMBOL_BOUNDARY .. '\\@!')
  else
    Search.push(ctx.state, '\\<' .. quoted .. '\\>')
  end
end

local function line(ctx)
  local text = ctx.port:getText()
  if #text == 0 then
    return
  end
  local count = ctx.state:takeCount(1)
  local lastLine = text_.lineCount(text) - 1
  local caretLine = text_.lineOfOffset(text, Sel.primary(ctx).active)
  if ctx.state.selType == SelType.LINE and ctx.state.selExpand and Sel.hasSelection(Sel.primary(ctx)) then
    if Sel.backwardP(ctx) then
      local targetLine = math.max(caretLine - math.abs(count), 0)
      Sel.select(ctx, SelType.LINE, Sel.mark(ctx), text_.lineStart(text, targetLine), true)
    else
      local targetLine = math.min(caretLine + math.abs(count), lastLine)
      Sel.select(ctx, SelType.LINE, Sel.mark(ctx), text_.lineEnd(text, targetLine), true)
    end
    return
  end
  if count < 0 then
    local firstLine = math.max(caretLine + count + 1, 0)
    Sel.select(ctx, SelType.LINE, text_.lineEnd(text, caretLine), text_.lineStart(text, firstLine), true)
  else
    local finalLine = math.min(caretLine + count - 1, lastLine)
    Sel.select(ctx, SelType.LINE, text_.lineStart(text, caretLine), text_.lineEnd(text, finalLine), true)
  end
end

local function gotoLine(ctx)
  local input = ctx.ui:input('Goto line:')
  if input == nil then
    return
  end
  local text = ctx.port:getText()
  if #text == 0 then
    return
  end
  local targetLine = text_.parsedLineNumber(input, text_.lineCount(text))
  if targetLine == nil then
    return
  end
  Sel.select(ctx, SelType.LINE, text_.lineStart(text, targetLine), text_.lineEnd(text, targetLine), true)
end

function M.findTill(ctx, char, till)
  local count = ctx.state:takeCount(1)
  local text = ctx.port:getText()
  local caret = Sel.primary(ctx).active
  local target = text_.nthCharTarget(text, char, caret, math.abs(count), count < 0, till)
  if target < 0 then
    ctx.ui:hint('char not found: ' .. char)
    return
  end
  ctx.state.lastFind = char
  Sel.select(ctx, till and SelType.TILL or SelType.FIND, caret, target, false)
end

M.commands = {
  ['meow-left'] = function(ctx)
    moveChar(ctx, -ctx.state:takeCount(1))
  end,
  ['meow-right'] = function(ctx)
    moveChar(ctx, ctx.state:takeCount(1))
  end,
  ['meow-next'] = function(ctx)
    moveLine(ctx, ctx.state:takeCount(1))
  end,
  ['meow-prev'] = function(ctx)
    moveLine(ctx, -ctx.state:takeCount(1))
  end,
  ['meow-left-expand'] = function(ctx)
    moveExpand(ctx, -ctx.state:takeCount(1), 0)
  end,
  ['meow-right-expand'] = function(ctx)
    moveExpand(ctx, ctx.state:takeCount(1), 0)
  end,
  ['meow-next-expand'] = function(ctx)
    moveExpand(ctx, 0, ctx.state:takeCount(1))
  end,
  ['meow-prev-expand'] = function(ctx)
    moveExpand(ctx, 0, -ctx.state:takeCount(1))
  end,
  ['meow-next-word'] = function(ctx)
    wordMotion(ctx, false, ctx.state:takeCount(1))
  end,
  ['meow-next-symbol'] = function(ctx)
    wordMotion(ctx, true, ctx.state:takeCount(1))
  end,
  ['meow-back-word'] = function(ctx)
    wordMotion(ctx, false, -ctx.state:takeCount(1))
  end,
  ['meow-back-symbol'] = function(ctx)
    wordMotion(ctx, true, -ctx.state:takeCount(1))
  end,
  ['meow-mark-word'] = function(ctx)
    markWord(ctx, false)
  end,
  ['meow-mark-symbol'] = function(ctx)
    markWord(ctx, true)
  end,
  ['meow-line'] = line,
  ['meow-goto-line'] = gotoLine,
  ['meow-find'] = function(ctx)
    ctx.state.pending = Pending.FIND
  end,
  ['meow-till'] = function(ctx)
    ctx.state.pending = Pending.TILL
  end,
  ['forward-char'] = function(ctx)
    charOrExpand(ctx, ctx.state:takeCount(1))
  end,
  ['backward-char'] = function(ctx)
    charOrExpand(ctx, -ctx.state:takeCount(1))
  end,
  ['next-line'] = function(ctx)
    lineOrExpand(ctx, ctx.state:takeCount(1))
    ctx.state.lastCommand = 'next-line'
  end,
  ['previous-line'] = function(ctx)
    lineOrExpand(ctx, -ctx.state:takeCount(1))
    ctx.state.lastCommand = 'previous-line'
  end,
  ['move-beginning-of-line'] = function(ctx)
    moveToOrExpand(ctx, SelType.CHAR, lineStartTarget)
  end,
  ['move-end-of-line'] = function(ctx)
    moveToOrExpand(ctx, SelType.CHAR, lineEndTarget)
  end,
  ['back-to-indentation'] = function(ctx)
    moveToOrExpand(ctx, SelType.CHAR, indentationTarget)
  end,
  ['forward-word'] = function(ctx)
    wordOrExpand(ctx, ctx.state:takeCount(1))
  end,
  ['backward-word'] = function(ctx)
    wordOrExpand(ctx, -ctx.state:takeCount(1))
  end,
  ['forward-sentence'] = function(ctx)
    sentenceOrExpand(ctx, ctx.state:takeCount(1))
  end,
  ['backward-sentence'] = function(ctx)
    sentenceOrExpand(ctx, -ctx.state:takeCount(1))
  end,
  ['beginning-of-buffer'] = function(ctx)
    bufferBoundary(ctx, true)
  end,
  ['end-of-buffer'] = function(ctx)
    bufferBoundary(ctx, false)
  end,
  ['forward-paragraph'] = function(ctx)
    paragraphOrExpand(ctx, ctx.state:takeCount(1))
  end,
  ['backward-paragraph'] = function(ctx)
    paragraphOrExpand(ctx, -ctx.state:takeCount(1))
  end,
}

return M
