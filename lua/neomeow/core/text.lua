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

local M = {}

local NL = string.byte('\n')
local CR = string.byte('\r')

function M.clamp(n, lo, hi)
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

function M.charAt(text, offset)
  return text:sub(offset + 1, offset + 1)
end

function M.slice(text, from, to)
  if to == nil then
    return text:sub(from + 1)
  end
  return text:sub(from + 1, to)
end

function M.regexQuote(s)
  return (s:gsub('[%^%$%.%*%~%[%]\\]', '\\%0'))
end

function M.lineOfOffset(text, offset)
  local ln = 0
  local last = M.clamp(offset, 0, #text)
  for i = 1, last do
    if text:byte(i) == NL then
      ln = ln + 1
    end
  end
  return ln
end

function M.lineCount(text)
  local n = 1
  for i = 1, #text do
    if text:byte(i) == NL then
      n = n + 1
    end
  end
  return n
end

function M.lineStart(text, line)
  if line <= 0 then
    return 0
  end
  local ln = 0
  for i = 1, #text do
    if text:byte(i) == NL then
      ln = ln + 1
      if ln == line then
        return i
      end
    end
  end
  return #text
end

function M.lineEnd(text, line)
  local s = M.lineStart(text, line)
  local nl1 = text:find('\n', s + 1, true)
  if nl1 == nil then
    return #text
  end
  local nl = nl1 - 1
  if nl > s and text:byte(nl1 - 1) == CR then
    return nl - 1
  end
  return nl
end

function M.isBlankLine(text, line)
  return M.slice(text, M.lineStart(text, line), M.lineEnd(text, line)):match('^%s*$') ~= nil
end

local function isWordChar(c)
  local b = c:byte(1)
  if b == nil then
    return false
  end
  return b >= 128 or c:match('^%w$') ~= nil
end

function M.isSymbolChar(c)
  return isWordChar(c) or c == '_' or c == '$'
end

function M.charPred(symbol)
  if symbol then
    return M.isSymbolChar
  end
  return isWordChar
end

local function isSpaceChar(c)
  return c:match('^%s$') ~= nil
end

local function indexOfChar(text, c, from)
  local i = from
  if i < 0 then
    i = 0
  end
  while i < #text do
    if M.charAt(text, i) == c then
      return i
    end
    i = i + 1
  end
  return -1
end

local function lastIndexOfChar(text, c, from)
  local i = from
  if i > #text - 1 then
    i = #text - 1
  end
  while i >= 0 do
    if M.charAt(text, i) == c then
      return i
    end
    i = i - 1
  end
  return -1
end

function M.nthCharTarget(text, ch, caret, n, backward, till)
  local found = -1
  local from
  if backward and till then
    from = caret - 2
  elseif backward then
    from = caret - 1
  elseif till then
    from = caret + 1
  else
    from = caret
  end
  for _ = 1, n do
    if backward then
      found = lastIndexOfChar(text, ch, from)
    else
      found = indexOfChar(text, ch, from)
    end
    if found < 0 then
      return -1
    end
    if backward then
      from = found - 1
    else
      from = found + 1
    end
  end
  if found < 0 then
    return -1
  end
  if backward then
    if till then
      return found + 1
    end
    return found
  end
  if till then
    return found
  end
  return found + 1
end

M.SENTENCE_ENDERS = '.!?'

local function isSentenceEnder(c)
  return c ~= '' and M.SENTENCE_ENDERS:find(c, 1, true) ~= nil
end

function M.nextSentenceEnd(text, from, n)
  local i = M.clamp(from, 0, #text)
  for _ = 1, n do
    while i < #text and not isSentenceEnder(M.charAt(text, i)) do
      i = i + 1
    end
    while i < #text and isSentenceEnder(M.charAt(text, i)) do
      i = i + 1
    end
    while i < #text and isSpaceChar(M.charAt(text, i)) do
      i = i + 1
    end
  end
  return i
end

function M.prevSentenceStart(text, from, n)
  local function isGap(c)
    return isSpaceChar(c) or isSentenceEnder(c)
  end
  local i = M.clamp(from, 0, #text)
  for _ = 1, n do
    while i > 0 and isGap(M.charAt(text, i - 1)) do
      i = i - 1
    end
    while i > 0 and not isGap(M.charAt(text, i - 1)) do
      i = i - 1
    end
  end
  return i
end

local function lineStartAt(text, offset)
  local i = offset
  while i > 0 and text:byte(i) ~= NL do
    i = i - 1
  end
  return i
end

local function followingLineStart(text, bol)
  local i = bol
  while i < #text and text:byte(i + 1) ~= NL do
    i = i + 1
  end
  if i < #text then
    return i + 1
  end
  return i
end

local function blankLineAt(text, bol)
  local i = bol
  while i < #text and text:byte(i + 1) ~= NL do
    if not isSpaceChar(M.charAt(text, i)) then
      return false
    end
    i = i + 1
  end
  return true
end

function M.nextParagraphEnd(text, from, n)
  local pos = M.clamp(from, 0, #text)
  for _ = 1, n do
    local i = lineStartAt(text, pos)
    while i < #text and blankLineAt(text, i) do
      i = followingLineStart(text, i)
    end
    while i < #text and not blankLineAt(text, i) do
      i = followingLineStart(text, i)
    end
    pos = i
  end
  return pos
end

local function paragraphStartBefore(text, offset)
  local i = lineStartAt(text, offset)
  while i > 0 and blankLineAt(text, i) do
    i = lineStartAt(text, i - 1)
  end
  while i > 0 and not blankLineAt(text, lineStartAt(text, i - 1)) do
    i = lineStartAt(text, i - 1)
  end
  local prevLineEmpty = i > 0 and text:byte(i) == NL and (i == 1 or text:byte(i - 1) == NL)
  if prevLineEmpty then
    return i - 1
  end
  return i
end

function M.prevParagraphStart(text, from, n)
  local pos = M.clamp(from, 0, #text)
  for _ = 1, n do
    if pos > 0 then
      local start = paragraphStartBefore(text, pos)
      if start < pos then
        pos = start
      else
        pos = paragraphStartBefore(text, start - 1)
      end
    end
  end
  return pos
end

function M.parsedLineNumber(input, lineCount)
  if input == nil then
    return nil
  end
  local digits = input:match('^%s*(%-?%d+)%s*$')
  if digits == nil then
    return nil
  end
  local maxLine = lineCount - 1
  if maxLine < 0 then
    maxLine = 0
  end
  return M.clamp(tonumber(digits) - 1, 0, maxLine)
end

M.Words = {}

function M.Words.nextEnd(text, from, n, pred)
  local i = M.clamp(from, 0, #text)
  for _ = 1, n do
    while i < #text and not pred(M.charAt(text, i)) do
      i = i + 1
    end
    while i < #text and pred(M.charAt(text, i)) do
      i = i + 1
    end
  end
  return i
end

function M.Words.prevStart(text, from, n, pred)
  local i = M.clamp(from, 0, #text)
  for _ = 1, n do
    while i > 0 and not pred(M.charAt(text, i - 1)) do
      i = i - 1
    end
    while i > 0 and pred(M.charAt(text, i - 1)) do
      i = i - 1
    end
  end
  return i
end

function M.Words.move(text, from, n, pred)
  if n >= 0 then
    return M.Words.nextEnd(text, from, n, pred)
  end
  return M.Words.prevStart(text, from, -n, pred)
end

function M.Words.spanAt(text, offset, pred)
  local s = offset
  local e = offset
  while s > 0 and pred(M.charAt(text, s - 1)) do
    s = s - 1
  end
  while e < #text and pred(M.charAt(text, e)) do
    e = e + 1
  end
  return s, e
end

function M.Words.boundsAt(text, offset, pred)
  local o = offset
  if o >= #text or not pred(M.charAt(text, o)) then
    if o > 0 and pred(M.charAt(text, o - 1)) then
      o = o - 1
    else
      local f = o
      while f < #text and not pred(M.charAt(text, f)) do
        f = f + 1
      end
      if f >= #text then
        return nil
      end
      o = f
    end
  end
  local s, e = M.Words.spanAt(text, o, pred)
  return { s, e }
end

function M.Words.fixSelectionMark(text, pos, mark, pred)
  local probeMax = #text - 1
  if probeMax < 0 then
    probeMax = 0
  end
  local probe = M.clamp(mark > pos and pos or pos - 1, 0, probeMax)
  local bounds = M.Words.boundsAt(text, probe, pred)
  if bounds == nil then
    return mark
  end
  if mark > pos then
    return math.min(mark, bounds[2])
  end
  return math.max(mark, bounds[1])
end

return M
