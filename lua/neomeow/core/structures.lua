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
local Things = require('neomeow.core.things').Things
local Sel = require('neomeow.core.selections')

local M = {}

local function pendThing(ctx, pending)
  ctx.state.pending = pending
  ctx.ui:scheduleWhichKey('things', '')
end

function M.thingSelect(ctx, kind, char)
  local caret = Sel.primary(ctx).active
  local bounds
  if kind == Pending.BOUNDS then
    bounds = Things.bounds(ctx, char, caret)
  else
    bounds = Things.inner(ctx, char, caret)
  end
  if bounds == nil then
    ctx.ui:hint("No thing '" .. char .. "' here")
    return
  end
  if kind == Pending.INNER then
    Sel.select(ctx, SelType.TRANSIENT, bounds.start, bounds.stop, false)
  elseif kind == Pending.BOUNDS then
    Sel.select(ctx, SelType.TRANSIENT, bounds.stop, bounds.start, false)
  elseif kind == Pending.BEGIN then
    Sel.select(ctx, SelType.TRANSIENT, caret, bounds.start, false)
  elseif kind == Pending.END_ then
    Sel.select(ctx, SelType.TRANSIENT, caret, bounds.stop, false)
  end
end

local function enclosingPair(text, selStart, selEnd)
  local opens = '([{'
  local closes = ')]}'
  local stack = {}
  local best = nil
  local i = 0
  while i < #text do
    local char = text_.charAt(text, i)
    if char == '"' or char == "'" or char == '`' then
      local j = i + 1
      while j < #text and text_.charAt(text, j) ~= char and text_.charAt(text, j) ~= '\n' do
        if text_.charAt(text, j) == '\\' then
          j = j + 1
        end
        j = j + 1
      end
      if j < #text and text_.charAt(text, j) == char then
        i = j + 1
      else
        i = i + 1
      end
    else
      if opens:find(char, 1, true) ~= nil then
        table.insert(stack, i)
      elseif closes:find(char, 1, true) ~= nil then
        local kind = closes:find(char, 1, true)
        while #stack > 0 do
          local openOffset = table.remove(stack)
          if opens:find(text_.charAt(text, openOffset), 1, true) == kind then
            local narrower = best == nil or i - openOffset < best.close - best.open
            if openOffset < selStart and i + 1 >= selEnd and narrower then
              best = { open = openOffset, close = i }
            end
            break
          end
        end
      end
      i = i + 1
    end
  end
  return best
end

local function block(ctx)
  local text = ctx.port:getText()
  local sel = Sel.primary(ctx)
  local active = ctx.state.selType == SelType.BLOCK and Sel.hasSelection(sel)
  local back = Sel.backwardP(ctx) ~= (ctx.state:takeCount(1) < 0)
  local selStart = active and Sel.selStart(sel) or sel.active
  local selEnd = active and Sel.selEnd(sel) or sel.active
  local braces = enclosingPair(text, selStart, selEnd)
  if braces == nil then
    ctx.ui:hint('No enclosing block')
    return
  end
  if back then
    Sel.select(ctx, SelType.BLOCK, braces.close + 1, braces.open, true)
  else
    Sel.select(ctx, SelType.BLOCK, braces.open, braces.close + 1, true)
  end
end

local function toBlock(ctx)
  local text = ctx.port:getText()
  local back = (ctx.state.selType == SelType.BLOCK and Sel.backwardP(ctx)) or ctx.state:takeCount(1) < 0
  local caret = Sel.primary(ctx).active
  local braces = enclosingPair(text, caret, caret)
  if braces == nil then
    ctx.ui:hint('No enclosing block')
    return
  end
  Sel.select(ctx, SelType.BLOCK, caret, back and braces.open or (braces.close + 1), true)
end

local function firstNonBlankOffset(text, line)
  local offset = text_.lineStart(text, line)
  local eol = text_.lineEnd(text, line)
  while offset < eol and text_.charAt(text, offset):match('^%s$') ~= nil do
    offset = offset + 1
  end
  return offset
end

local function selectJoin(ctx, text, markLine, pointLine)
  local mark = text_.lineEnd(text, markLine)
  Sel.select(ctx, SelType.JOIN, mark, firstNonBlankOffset(text, pointLine), true)
end

local function join(ctx)
  local text = ctx.port:getText()
  if #text == 0 then
    return
  end
  local count = ctx.state:takeCount(1)
  local function blank(lineIndex)
    return text_.isBlankLine(text, lineIndex)
  end
  local caretLine = text_.lineOfOffset(text, Sel.primary(ctx).active)
  if count >= 0 then
    local previousLine = caretLine - 1
    while previousLine >= 0 and blank(previousLine) do
      previousLine = previousLine - 1
    end
    if previousLine < 0 then
      return
    end
    selectJoin(ctx, text, previousLine, caretLine)
  else
    local lastLine = text_.lineCount(text) - 1
    local nextLine = caretLine + 1
    while nextLine <= lastLine and blank(nextLine) do
      nextLine = nextLine + 1
    end
    if nextLine > lastLine then
      return
    end
    selectJoin(ctx, text, caretLine, nextLine)
  end
end

M.commands = {
  ['meow-inner-of-thing'] = function(ctx)
    pendThing(ctx, Pending.INNER)
  end,
  ['meow-bounds-of-thing'] = function(ctx)
    pendThing(ctx, Pending.BOUNDS)
  end,
  ['meow-beginning-of-thing'] = function(ctx)
    pendThing(ctx, Pending.BEGIN)
  end,
  ['meow-end-of-thing'] = function(ctx)
    pendThing(ctx, Pending.END_)
  end,
  ['meow-block'] = block,
  ['meow-to-block'] = toBlock,
  ['meow-join'] = join,
}

return M
