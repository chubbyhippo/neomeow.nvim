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

function M.clamp(value, min, max)
  if value < min then
    return min
  end
  if value > max then
    return max
  end
  return value
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

function M.regexQuote(text)
  return (text:gsub('[%^%$%.%*%~%[%]\\]', '\\%0'))
end

function M.lineOfOffset(text, offset)
  local line = 0
  local last = M.clamp(offset, 0, #text)
  for i = 1, last do
    if text:byte(i) == NL then
      line = line + 1
    end
  end
  return line
end

function M.lineCount(text)
  local count = 1
  for i = 1, #text do
    if text:byte(i) == NL then
      count = count + 1
    end
  end
  return count
end

function M.lineStart(text, line)
  if line <= 0 then
    return 0
  end
  local seen = 0
  for i = 1, #text do
    if text:byte(i) == NL then
      seen = seen + 1
      if seen == line then
        return i
      end
    end
  end
  return #text
end

function M.lineEnd(text, line)
  local lineStartOffset = M.lineStart(text, line)
  local newlineAt = text:find('\n', lineStartOffset + 1, true)
  if newlineAt == nil then
    return #text
  end
  local endOffset = newlineAt - 1
  if endOffset > lineStartOffset and text:byte(newlineAt - 1) == CR then
    return endOffset - 1
  end
  return endOffset
end

function M.isBlankLine(text, line)
  return M.slice(text, M.lineStart(text, line), M.lineEnd(text, line)):match('^%s*$') ~= nil
end

local function isWordChar(char)
  local byte = char:byte(1)
  if byte == nil then
    return false
  end
  return byte >= 128 or char:match('^%w$') ~= nil
end

function M.isSymbolChar(char)
  return isWordChar(char) or char == '_' or char == '$'
end

function M.charPred(symbol)
  if symbol then
    return M.isSymbolChar
  end
  return isWordChar
end

local function isSpaceChar(char)
  return char:match('^%s$') ~= nil
end

local function indexOfChar(text, char, from)
  local i = from
  if i < 0 then
    i = 0
  end
  while i < #text do
    if M.charAt(text, i) == char then
      return i
    end
    i = i + 1
  end
  return -1
end

local function lastIndexOfChar(text, char, from)
  local i = from
  if i > #text - 1 then
    i = #text - 1
  end
  while i >= 0 do
    if M.charAt(text, i) == char then
      return i
    end
    i = i - 1
  end
  return -1
end

function M.nthCharTarget(text, char, caret, count, backward, till)
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
  for _ = 1, count do
    if backward then
      found = lastIndexOfChar(text, char, from)
    else
      found = indexOfChar(text, char, from)
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

local function isSentenceEnder(char)
  return char ~= '' and M.SENTENCE_ENDERS:find(char, 1, true) ~= nil
end

function M.nextSentenceEnd(text, from, count)
  local i = M.clamp(from, 0, #text)
  for _ = 1, count do
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

function M.prevSentenceStart(text, from, count)
  local function isGap(char)
    return isSpaceChar(char) or isSentenceEnder(char)
  end
  local i = M.clamp(from, 0, #text)
  for _ = 1, count do
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

local function followingLineStart(text, lineStartOffset)
  local i = lineStartOffset
  while i < #text and text:byte(i + 1) ~= NL do
    i = i + 1
  end
  if i < #text then
    return i + 1
  end
  return i
end

local function blankLineAt(text, lineStartOffset)
  local i = lineStartOffset
  while i < #text and text:byte(i + 1) ~= NL do
    if not isSpaceChar(M.charAt(text, i)) then
      return false
    end
    i = i + 1
  end
  return true
end

function M.nextParagraphEnd(text, from, count)
  local pos = M.clamp(from, 0, #text)
  for _ = 1, count do
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

function M.prevParagraphStart(text, from, count)
  local pos = M.clamp(from, 0, #text)
  for _ = 1, count do
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

function M.Words.nextEnd(text, from, count, isWord)
  local i = M.clamp(from, 0, #text)
  for _ = 1, count do
    while i < #text and not isWord(M.charAt(text, i)) do
      i = i + 1
    end
    while i < #text and isWord(M.charAt(text, i)) do
      i = i + 1
    end
  end
  return i
end

function M.Words.prevStart(text, from, count, isWord)
  local i = M.clamp(from, 0, #text)
  for _ = 1, count do
    while i > 0 and not isWord(M.charAt(text, i - 1)) do
      i = i - 1
    end
    while i > 0 and isWord(M.charAt(text, i - 1)) do
      i = i - 1
    end
  end
  return i
end

function M.Words.move(text, from, count, isWord)
  if count >= 0 then
    return M.Words.nextEnd(text, from, count, isWord)
  end
  return M.Words.prevStart(text, from, -count, isWord)
end

function M.Words.spanAt(text, offset, isWord)
  local startOffset = offset
  local endOffset = offset
  while startOffset > 0 and isWord(M.charAt(text, startOffset - 1)) do
    startOffset = startOffset - 1
  end
  while endOffset < #text and isWord(M.charAt(text, endOffset)) do
    endOffset = endOffset + 1
  end
  return startOffset, endOffset
end

local function offsetInWord(text, offset, isWord)
  if offset < #text and isWord(M.charAt(text, offset)) then
    return offset
  end
  if offset > 0 and isWord(M.charAt(text, offset - 1)) then
    return offset - 1
  end
  local scan = offset
  while scan < #text and not isWord(M.charAt(text, scan)) do
    scan = scan + 1
  end
  if scan >= #text then
    return nil
  end
  return scan
end

function M.Words.boundsAt(text, offset, isWord)
  local inWord = offsetInWord(text, offset, isWord)
  if inWord == nil then
    return nil
  end
  local startOffset, endOffset = M.Words.spanAt(text, inWord, isWord)
  return { startOffset, endOffset }
end

function M.Words.fixSelectionMark(text, pos, mark, isWord)
  local probeMax = #text - 1
  if probeMax < 0 then
    probeMax = 0
  end
  local probe = M.clamp(mark > pos and pos or pos - 1, 0, probeMax)
  local bounds = M.Words.boundsAt(text, probe, isWord)
  if bounds == nil then
    return mark
  end
  if mark > pos then
    return math.min(mark, bounds[2])
  end
  return math.max(mark, bounds[1])
end

function M.isBlank(char)
  return char == ' ' or char == '\t'
end

function M.firstNonBlankOffset(text, from, stop)
  local at = from
  while at < stop and M.isBlank(M.charAt(text, at)) do
    at = at + 1
  end
  return at
end

return M
