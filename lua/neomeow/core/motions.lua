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
local state = require('neomeow.core.state')
local SelType = state.SelType
local Pending = state.Pending
local Sel = require('neomeow.core.selections')
local Search = require('neomeow.core.search')

local M = {}

local function lineStartTarget(text, off)
  return text_.lineStart(text, text_.lineOfOffset(text, off))
end

local function lineEndTarget(text, off)
  return text_.lineEnd(text, text_.lineOfOffset(text, off))
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
  return ctx.st.selType == SelType.CHAR and Sel.hasSelection(Sel.primary(ctx))
end

local function movedChar(len, sel, dx, extend)
  local active = text_.clamp(sel.active + dx, 0, len)
  return { anchor = extend and sel.anchor or active, active = active }
end

local function movedLine(text, sel, dy, extend, goal)
  local ln = text_.lineOfOffset(text, sel.active)
  local target = ln + dy
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
      col = sel.active - text_.lineStart(text, ln)
    end
    local bol = text_.lineStart(text, target)
    active = bol + math.min(col, text_.lineEnd(text, target) - bol)
  end
  return { anchor = extend and sel.anchor or active, active = active }
end

local function goalColumn(ctx)
  local st = ctx.st
  if st.goalColumn == nil or st.lastCommand == nil or not VERTICAL[st.lastCommand] then
    local text = ctx.port:getText()
    local p = Sel.primary(ctx).active
    st.goalColumn = p - text_.lineStart(text, text_.lineOfOffset(text, p))
  end
  return st.goalColumn
end

local function moveChar(ctx, dx)
  local extend = charSelActive(ctx)
  if not extend and Sel.hasSelection(Sel.primary(ctx)) then
    Sel.cancel(ctx)
  end
  local len = #ctx.port:getText()
  local moved = {}
  for i, s in ipairs(ctx.port:getSelections()) do
    moved[i] = movedChar(len, s, dx, extend)
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
  for i, s in ipairs(ctx.port:getSelections()) do
    moved[i] = movedLine(text, s, dy, extend, i == 1 and goal or nil)
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
  for i, s in ipairs(sels) do
    if dy == 0 then
      moved[i] = movedChar(#text, s, dx, true)
    else
      moved[i] = movedLine(text, s, dy, true, i == 1 and goal or nil)
    end
  end
  ctx.port:setSelections(moved)
  Sel.recordSelect(ctx, SelType.CHAR, moved[1].anchor, moved[1].active, true, before)
  ctx.st.selType = SelType.CHAR
  ctx.st.selExpand = true
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
  for i, s in ipairs(ctx.port:getSelections()) do
    local active = text_.clamp(target(text, s.active), 0, #text)
    moved[i] = { anchor = extend and s.anchor or active, active = active }
  end
  ctx.port:setSelections(moved)
  if extend then
    Sel.recordSelect(ctx, type_, moved[1].anchor, moved[1].active, true, before)
    ctx.st.selType = type_
    ctx.st.selExpand = true
    require('neomeow.core.grab').beacon(ctx)
  end
end

local function wordOrExpand(ctx, n)
  local pred = text_.charPred(false)
  moveToOrExpand(ctx, SelType.WORD, function(text, off)
    if n >= 0 then
      return text_.Words.nextEnd(text, off, n, pred)
    end
    return text_.Words.prevStart(text, off, -n, pred)
  end)
end

local function sentenceOrExpand(ctx, n)
  moveToOrExpand(ctx, SelType.CHAR, function(text, off)
    if n >= 0 then
      return text_.nextSentenceEnd(text, off, n)
    end
    return text_.prevSentenceStart(text, off, -n)
  end)
end

local function paragraphOrExpand(ctx, n)
  moveToOrExpand(ctx, SelType.CHAR, function(text, off)
    if n >= 0 then
      return text_.nextParagraphEnd(text, off, n)
    end
    return text_.prevParagraphStart(text, off, -n)
  end)
end

local function nextLineStart(text, offset)
  if #text == 0 then
    return 0
  end
  local ln = text_.lineOfOffset(text, text_.clamp(offset, 0, #text))
  if ln >= text_.lineCount(text) - 1 then
    return #text
  end
  return text_.lineStart(text, ln + 1)
end

local function bufferBoundary(ctx, top)
  local counted = ctx.st.pendingCount ~= 0 or ctx.st.negative
  local n = ctx.st:takeCount(1)
  moveToOrExpand(ctx, SelType.CHAR, function(text)
    local len = #text
    if not counted then
      if top then
        return 0
      end
      return len
    end
    local q = len * n / 10
    local tenth = q >= 0 and math.floor(q) or math.ceil(q)
    local raw = text_.clamp(top and tenth or len - tenth, 0, len)
    return nextLineStart(text, raw)
  end)
end

local function wordMotion(ctx, symbol, n)
  if n == 0 then
    return
  end
  local text = ctx.port:getText()
  local type_ = wordType(symbol)
  local sel = Sel.primary(ctx)
  local lo = math.min(sel.anchor, sel.active)
  local hi = math.max(sel.anchor, sel.active)
  if not (Sel.hasSelection(sel) and ctx.st.selType == type_) then
    Sel.cancel(ctx)
  end
  local extend = ctx.st.selExpand and ctx.st.selType == type_ and Sel.hasSelection(sel)
  local from
  if extend then
    from = n < 0 and lo or hi
  else
    from = sel.active
  end
  local target
  if n > 0 then
    target = text_.Words.nextEnd(text, from, n, text_.charPred(symbol))
  else
    target = text_.Words.prevStart(text, from, -n, text_.charPred(symbol))
  end
  if target == from then
    return
  end
  local anchor
  if extend then
    anchor = n < 0 and hi or lo
  else
    anchor = text_.Words.fixSelectionMark(text, target, from, text_.charPred(symbol))
  end
  Sel.select(ctx, type_, anchor, target, extend)
end

local SYMBOL_BOUNDARY = '\\%([0-9A-Za-z_$]\\)'

local function markWord(ctx, symbol)
  local neg = ctx.st:takeCount(1) < 0
  local text = ctx.port:getText()
  local b = text_.Words.boundsAt(text, Sel.primary(ctx).active, text_.charPred(symbol))
  if b == nil then
    ctx.ui:hint('No word here')
    return
  end
  local s = b[1]
  local e = b[2]
  if neg then
    Sel.select(ctx, wordType(symbol), e, s, true)
  else
    Sel.select(ctx, wordType(symbol), s, e, true)
  end
  local quoted = text_.regexQuote(text_.slice(text, s, e))
  if symbol then
    Search.push(ctx.st, SYMBOL_BOUNDARY .. '\\@<!' .. quoted .. SYMBOL_BOUNDARY .. '\\@!')
  else
    Search.push(ctx.st, '\\<' .. quoted .. '\\>')
  end
end

local function line(ctx)
  local text = ctx.port:getText()
  if #text == 0 then
    return
  end
  local n = ctx.st:takeCount(1)
  local lastLine = text_.lineCount(text) - 1
  if ctx.st.selType == SelType.LINE and ctx.st.selExpand and Sel.hasSelection(Sel.primary(ctx)) then
    local caretLn = text_.lineOfOffset(text, Sel.primary(ctx).active)
    if Sel.backwardP(ctx) then
      local ln = math.max(caretLn - math.abs(n), 0)
      Sel.select(ctx, SelType.LINE, Sel.mark(ctx), text_.lineStart(text, ln), true)
    else
      local ln = math.min(caretLn + math.abs(n), lastLine)
      Sel.select(ctx, SelType.LINE, Sel.mark(ctx), text_.lineEnd(text, ln), true)
    end
    return
  end
  local ln = text_.lineOfOffset(text, Sel.primary(ctx).active)
  if n < 0 then
    local startLn = math.max(ln + n + 1, 0)
    Sel.select(ctx, SelType.LINE, text_.lineEnd(text, ln), text_.lineStart(text, startLn), true)
  else
    local endLn = math.min(ln + n - 1, lastLine)
    Sel.select(ctx, SelType.LINE, text_.lineStart(text, ln), text_.lineEnd(text, endLn), true)
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
  local ln = text_.parsedLineNumber(input, text_.lineCount(text))
  if ln == nil then
    return
  end
  Sel.select(ctx, SelType.LINE, text_.lineStart(text, ln), text_.lineEnd(text, ln), true)
end

function M.findTill(ctx, ch, till)
  local n = ctx.st:takeCount(1)
  local text = ctx.port:getText()
  local caret = Sel.primary(ctx).active
  local target = text_.nthCharTarget(text, ch, caret, math.abs(n), n < 0, till)
  if target < 0 then
    ctx.ui:hint('char not found: ' .. ch)
    return
  end
  ctx.st.lastFind = ch
  Sel.select(ctx, till and SelType.TILL or SelType.FIND, caret, target, false)
end

M.commands = {
  ['meow-left'] = function(ctx)
    moveChar(ctx, -ctx.st:takeCount(1))
  end,
  ['meow-right'] = function(ctx)
    moveChar(ctx, ctx.st:takeCount(1))
  end,
  ['meow-next'] = function(ctx)
    moveLine(ctx, ctx.st:takeCount(1))
  end,
  ['meow-prev'] = function(ctx)
    moveLine(ctx, -ctx.st:takeCount(1))
  end,
  ['meow-left-expand'] = function(ctx)
    moveExpand(ctx, -ctx.st:takeCount(1), 0)
  end,
  ['meow-right-expand'] = function(ctx)
    moveExpand(ctx, ctx.st:takeCount(1), 0)
  end,
  ['meow-next-expand'] = function(ctx)
    moveExpand(ctx, 0, ctx.st:takeCount(1))
  end,
  ['meow-prev-expand'] = function(ctx)
    moveExpand(ctx, 0, -ctx.st:takeCount(1))
  end,
  ['meow-next-word'] = function(ctx)
    wordMotion(ctx, false, ctx.st:takeCount(1))
  end,
  ['meow-next-symbol'] = function(ctx)
    wordMotion(ctx, true, ctx.st:takeCount(1))
  end,
  ['meow-back-word'] = function(ctx)
    wordMotion(ctx, false, -ctx.st:takeCount(1))
  end,
  ['meow-back-symbol'] = function(ctx)
    wordMotion(ctx, true, -ctx.st:takeCount(1))
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
    ctx.st.pending = Pending.FIND
  end,
  ['meow-till'] = function(ctx)
    ctx.st.pending = Pending.TILL
  end,
  ['forward-char'] = function(ctx)
    charOrExpand(ctx, ctx.st:takeCount(1))
  end,
  ['backward-char'] = function(ctx)
    charOrExpand(ctx, -ctx.st:takeCount(1))
  end,
  ['next-line'] = function(ctx)
    lineOrExpand(ctx, ctx.st:takeCount(1))
    ctx.st.lastCommand = 'next-line'
  end,
  ['previous-line'] = function(ctx)
    lineOrExpand(ctx, -ctx.st:takeCount(1))
    ctx.st.lastCommand = 'previous-line'
  end,
  ['move-beginning-of-line'] = function(ctx)
    moveToOrExpand(ctx, SelType.CHAR, lineStartTarget)
  end,
  ['move-end-of-line'] = function(ctx)
    moveToOrExpand(ctx, SelType.CHAR, lineEndTarget)
  end,
  ['forward-word'] = function(ctx)
    wordOrExpand(ctx, ctx.st:takeCount(1))
  end,
  ['backward-word'] = function(ctx)
    wordOrExpand(ctx, -ctx.st:takeCount(1))
  end,
  ['forward-sentence'] = function(ctx)
    sentenceOrExpand(ctx, ctx.st:takeCount(1))
  end,
  ['backward-sentence'] = function(ctx)
    sentenceOrExpand(ctx, -ctx.st:takeCount(1))
  end,
  ['beginning-of-buffer'] = function(ctx)
    bufferBoundary(ctx, true)
  end,
  ['end-of-buffer'] = function(ctx)
    bufferBoundary(ctx, false)
  end,
  ['forward-paragraph'] = function(ctx)
    paragraphOrExpand(ctx, ctx.st:takeCount(1))
  end,
  ['backward-paragraph'] = function(ctx)
    paragraphOrExpand(ctx, -ctx.st:takeCount(1))
  end,
}

return M
