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
    local c = text_.charAt(text, i)
    if c == close then
      depth = depth + 1
    elseif c == open then
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
    local c = text_.charAt(text, j)
    if c == open and j ~= start then
      depth = depth + 1
    elseif c == close then
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
  local n = #text
  local i = 0
  while i < n do
    local c = text_.charAt(text, i)
    if c == '"' or c == "'" or c == '`' then
      local triple = i + 2 < n and text_.charAt(text, i + 1) == c and text_.charAt(text, i + 2) == c
      local len = triple and 3 or 1
      local open = i
      local j = i + len
      local closeEnd = -1
      while j < n do
        local d = text_.charAt(text, j)
        if not triple and d == '\n' then
          break
        end
        if d == '\\' then
          j = j + 2
        else
          local closes = true
          if triple then
            closes = j + 2 < n and text_.charAt(text, j + 1) == c and text_.charAt(text, j + 2) == c
          end
          if d == c and closes then
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
  local o = offset
  if o >= #text or not text_.isSymbolChar(text_.charAt(text, o)) then
    if o > 0 and text_.isSymbolChar(text_.charAt(text, o - 1)) then
      o = o - 1
    else
      return nil
    end
  end
  local s = o
  local e = o
  while s > 0 and text_.isSymbolChar(text_.charAt(text, s - 1)) do
    s = s - 1
  end
  while e < #text and text_.isSymbolChar(text_.charAt(text, e)) do
    e = e + 1
  end
  return { start = s, stop = e }
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
  local function blank(l)
    return text_.isBlankLine(text, l)
  end
  local ln = text_.lineOfOffset(text, text_.clamp(offset, 0, #text))
  if blank(ln) then
    return nil
  end
  local first = ln
  local last = ln
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
  local e
  if stop < count - 1 then
    e = text_.lineStart(text, stop + 1)
  else
    e = text_.lineEnd(text, stop)
  end
  return { start = start, stop = e }
end

local function line(text, offset, inner)
  local ln = text_.lineOfOffset(text, text_.clamp(offset, 0, #text))
  local stop = text_.lineEnd(text, ln)
  if inner then
    return { start = text_.lineStart(text, ln), stop = stop }
  end
  return { start = text_.lineStart(text, ln), stop = text_.lineStart(text, ln + 1) }
end

local function visualLine(text, offset)
  return line(text, offset, true)
end

local function defun(ctx, text, offset)
  local fromHost = ctx.port:symbolRangeAt(offset)
  if fromHost ~= nil then
    return fromHost
  end
  local b = pair(text, offset, '{', '}', false)
  if b == nil then
    return nil
  end
  while true do
    local outer = pair(text, b.start, '{', '}', false)
    if outer == nil then
      break
    end
    b = outer
  end
  return b
end

local function isEnder(c)
  return c ~= '' and text_.SENTENCE_ENDERS:find(c, 1, true) ~= nil
end

local function sentence(text, offset, inner)
  if #text == 0 then
    return nil
  end
  local s = text_.clamp(offset, 0, #text - 1)
  while s > 0 do
    local c = text_.charAt(text, s - 1)
    if isEnder(c) or (c == '\n' and s > 1 and text_.charAt(text, s - 2) == '\n') then
      break
    end
    s = s - 1
  end
  while s < #text and text_.charAt(text, s):match('^%s$') ~= nil do
    s = s + 1
  end
  local e = text_.clamp(offset, 0, #text)
  while
    e < #text
    and not isEnder(text_.charAt(text, e))
    and not (text_.charAt(text, e) == '\n' and e + 1 < #text and text_.charAt(text, e + 1) == '\n')
  do
    e = e + 1
  end
  if e < #text and isEnder(text_.charAt(text, e)) then
    e = e + 1
  end
  if e <= s then
    return nil
  end
  if inner then
    return { start = s, stop = e }
  end
  local be = e
  while be < #text and text_.charAt(text, be) == ' ' do
    be = be + 1
  end
  return { start = s, stop = be }
end

local function compute(ctx, ch, offset, inner)
  local text = ctx.port:getText()
  if ch == 'r' then
    return pair(text, offset, '(', ')', inner)
  elseif ch == 's' then
    return pair(text, offset, '[', ']', inner)
  elseif ch == 'c' then
    return pair(text, offset, '{', '}', inner)
  elseif ch == 'g' then
    return stringThing(text, offset, inner)
  elseif ch == 'e' then
    return symbol(text, offset)
  elseif ch == 'w' then
    return window(ctx, text)
  elseif ch == 'b' then
    return { start = 0, stop = #text }
  elseif ch == 'p' then
    return paragraph(text, offset, inner)
  elseif ch == 'l' then
    return line(text, offset, inner)
  elseif ch == 'v' then
    return visualLine(text, offset)
  elseif ch == 'd' then
    return defun(ctx, text, offset)
  elseif ch == '.' then
    return sentence(text, offset, inner)
  end
  return nil
end

M.Things = {
  inner = function(ctx, ch, offset)
    return compute(ctx, ch, offset, true)
  end,
  bounds = function(ctx, ch, offset)
    return compute(ctx, ch, offset, false)
  end,
}

return M
