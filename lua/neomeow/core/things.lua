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

local M = {}

local function pair(text, offset, open, close, inner)
  local depth = 0
  local start = -1
  local i = offset - 1
  while i >= 0 do
    local char = text_.charAt(text, i)
    if char == close then
      depth = depth + 1
    elseif char == open then
      if depth == 0 then
        start = i
        break
      end
      depth = depth - 1
    end
    i = i - 1
  end
  if start < 0 then
    return nil
  end
  depth = 0
  local stop = -1
  local j = offset
  while j < #text do
    local char = text_.charAt(text, j)
    if char == open and j ~= start then
      depth = depth + 1
    elseif char == close then
      if depth == 0 then
        stop = j
        break
      end
      depth = depth - 1
    end
    j = j + 1
  end
  if stop < 0 then
    return nil
  end
  if inner then
    return { start = start + 1, stop = stop }
  end
  return { start = start, stop = stop + 1 }
end

local function stringThing(text, offset, inner)
  local textLength = #text
  local i = 0
  while i < textLength do
    local quote = text_.charAt(text, i)
    if quote == '"' or quote == "'" or quote == '`' then
      local triple = i + 2 < textLength and text_.charAt(text, i + 1) == quote and text_.charAt(text, i + 2) == quote
      local len = triple and 3 or 1
      local open = i
      local j = i + len
      local closeEnd = -1
      while j < textLength do
        local char = text_.charAt(text, j)
        if not triple and char == '\n' then
          break
        end
        if char == '\\' then
          j = j + 2
        else
          local closes = true
          if triple then
            closes = j + 2 < textLength and text_.charAt(text, j + 1) == quote and text_.charAt(text, j + 2) == quote
          end
          if char == quote and closes then
            closeEnd = j + len
            break
          end
          j = j + 1
        end
      end
      if closeEnd < 0 then
        i = open + len
      else
        if offset >= open and offset < closeEnd then
          if inner then
            return { start = open + len, stop = closeEnd - len }
          end
          return { start = open, stop = closeEnd }
        end
        i = closeEnd
      end
    else
      i = i + 1
    end
  end
  return nil
end

local function symbol(text, offset)
  local inSymbol = offset
  if inSymbol >= #text or not text_.isSymbolChar(text_.charAt(text, inSymbol)) then
    if inSymbol > 0 and text_.isSymbolChar(text_.charAt(text, inSymbol - 1)) then
      inSymbol = inSymbol - 1
    else
      return nil
    end
  end
  local startOffset = inSymbol
  local endOffset = inSymbol
  while startOffset > 0 and text_.isSymbolChar(text_.charAt(text, startOffset - 1)) do
    startOffset = startOffset - 1
  end
  while endOffset < #text and text_.isSymbolChar(text_.charAt(text, endOffset)) do
    endOffset = endOffset + 1
  end
  return { start = startOffset, stop = endOffset }
end

local function window(ctx, text)
  local vis = ctx.port:visibleLineRange()
  local last = text_.lineCount(text) - 1
  local maxLine = math.max(last, 0)
  local first = text_.clamp(vis ~= nil and vis.first or 0, 0, maxLine)
  local stop = text_.clamp(vis ~= nil and vis.last or last, 0, maxLine)
  return { start = text_.lineStart(text, first), stop = text_.lineEnd(text, stop) }
end

local function paragraph(text, offset, inner)
  if #text == 0 then
    return nil
  end
  local count = text_.lineCount(text)
  local function blank(lineIndex)
    return text_.isBlankLine(text, lineIndex)
  end
  local caretLine = text_.lineOfOffset(text, text_.clamp(offset, 0, #text))
  if blank(caretLine) then
    return nil
  end
  local first = caretLine
  local last = caretLine
  while first > 0 and not blank(first - 1) do
    first = first - 1
  end
  while last < count - 1 and not blank(last + 1) do
    last = last + 1
  end
  local start = text_.lineStart(text, first)
  if inner then
    return { start = start, stop = text_.lineEnd(text, last) }
  end
  local stop = last
  while stop < count - 1 and blank(stop + 1) do
    stop = stop + 1
  end
  local endOffset
  if stop < count - 1 then
    endOffset = text_.lineStart(text, stop + 1)
  else
    endOffset = text_.lineEnd(text, stop)
  end
  return { start = start, stop = endOffset }
end

local function line(text, offset, inner)
  local caretLine = text_.lineOfOffset(text, text_.clamp(offset, 0, #text))
  local stop = text_.lineEnd(text, caretLine)
  if inner then
    return { start = text_.lineStart(text, caretLine), stop = stop }
  end
  return { start = text_.lineStart(text, caretLine), stop = text_.lineStart(text, caretLine + 1) }
end

local function visualLine(text, offset)
  return line(text, offset, true)
end

local function defun(ctx, text, offset)
  local fromHost = ctx.port:symbolRangeAt(offset)
  if fromHost ~= nil then
    return fromHost
  end
  local braces = pair(text, offset, '{', '}', false)
  if braces == nil then
    return nil
  end
  while true do
    local outer = pair(text, braces.start, '{', '}', false)
    if outer == nil then
      break
    end
    braces = outer
  end
  return braces
end

local function isEnder(char)
  return char ~= '' and text_.SENTENCE_ENDERS:find(char, 1, true) ~= nil
end

local function sentence(text, offset, inner)
  if #text == 0 then
    return nil
  end
  local startOffset = text_.clamp(offset, 0, #text - 1)
  while startOffset > 0 do
    local char = text_.charAt(text, startOffset - 1)
    local blankLineBreak = char == '\n' and startOffset > 1 and text_.charAt(text, startOffset - 2) == '\n'
    if isEnder(char) or blankLineBreak then
      break
    end
    startOffset = startOffset - 1
  end
  while startOffset < #text and text_.charAt(text, startOffset):match('^%s$') ~= nil do
    startOffset = startOffset + 1
  end
  local endOffset = text_.clamp(offset, 0, #text)
  while
    endOffset < #text
    and not isEnder(text_.charAt(text, endOffset))
    and not (
      text_.charAt(text, endOffset) == '\n'
      and endOffset + 1 < #text
      and text_.charAt(text, endOffset + 1) == '\n'
    )
  do
    endOffset = endOffset + 1
  end
  if endOffset < #text and isEnder(text_.charAt(text, endOffset)) then
    endOffset = endOffset + 1
  end
  if endOffset <= startOffset then
    return nil
  end
  if inner then
    return { start = startOffset, stop = endOffset }
  end
  local withTrailingSpace = endOffset
  while withTrailingSpace < #text and text_.charAt(text, withTrailingSpace) == ' ' do
    withTrailingSpace = withTrailingSpace + 1
  end
  return { start = startOffset, stop = withTrailingSpace }
end

local function compute(ctx, char, offset, inner)
  local text = ctx.port:getText()
  if char == 'r' then
    return pair(text, offset, '(', ')', inner)
  elseif char == 's' then
    return pair(text, offset, '[', ']', inner)
  elseif char == 'c' then
    return pair(text, offset, '{', '}', inner)
  elseif char == 'g' then
    return stringThing(text, offset, inner)
  elseif char == 'e' then
    return symbol(text, offset)
  elseif char == 'w' then
    return window(ctx, text)
  elseif char == 'b' then
    return { start = 0, stop = #text }
  elseif char == 'p' then
    return paragraph(text, offset, inner)
  elseif char == 'l' then
    return line(text, offset, inner)
  elseif char == 'v' then
    return visualLine(text, offset)
  elseif char == 'd' then
    return defun(ctx, text, offset)
  elseif char == '.' then
    return sentence(text, offset, inner)
  end
  return nil
end

M.Things = {
  inner = function(ctx, char, offset)
    return compute(ctx, char, offset, true)
  end,
  bounds = function(ctx, char, offset)
    return compute(ctx, char, offset, false)
  end,
}

return M
