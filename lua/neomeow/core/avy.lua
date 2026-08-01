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
local Sel = require('neomeow.core.selections')

local M = {}

local KEYS = 'asdfghjkl'

M.TIMEOUT_MS = 250

function M.subdiv(n, b)
  local p = math.floor(math.log(n) / math.log(b) + 1e-6) - 1
  local x1 = 1
  for _ = 1, p do
    x1 = x1 * b
  end
  local x2 = b * x1
  local delta = n - x2
  local n2 = math.floor(delta / (x2 - x1))
  local n1 = b - n2 - 1
  local out = {}
  for _ = 1, n1 do
    table.insert(out, x1)
  end
  table.insert(out, n - n1 * x1 - n2 * x2)
  for _ = 1, n2 do
    table.insert(out, x2)
  end
  return out
end

local function tree(candidates, keys)
  keys = keys or KEYS
  if #candidates < #keys then
    local children = {}
    for i, offset in ipairs(candidates) do
      table.insert(children, { keys:sub(i, i), { kind = 'leaf', offset = offset } })
    end
    return { kind = 'branch', children = children }
  end
  local rest = candidates
  local children = {}
  for i, size in ipairs(M.subdiv(#candidates, #keys)) do
    local taken = {}
    for k = 1, size do
      taken[k] = rest[k]
    end
    local remaining = {}
    for k = size + 1, #rest do
      table.insert(remaining, rest[k])
    end
    rest = remaining
    if size == 1 then
      table.insert(children, { keys:sub(i, i), { kind = 'leaf', offset = taken[1] } })
    else
      table.insert(children, { keys:sub(i, i), tree(taken, keys) })
    end
  end
  return { kind = 'branch', children = children }
end

local function labels(node)
  local out = {}
  local function walk(n, path)
    if n.kind == 'leaf' then
      table.insert(out, { n.offset, path })
    else
      for _, pair in ipairs(n.children) do
        walk(pair[2], path .. pair[1])
      end
    end
  end
  walk(node, '')
  return out
end

function M.labelsFor(count)
  if count <= 0 then
    return {}
  end
  local indices = {}
  for i = 0, count - 1 do
    indices[i + 1] = i
  end
  local indexed = labels(tree(indices))
  table.sort(indexed, function(a, b)
    return a[1] < b[1]
  end)
  local out = {}
  for i, pair in ipairs(indexed) do
    out[i] = pair[2]
  end
  return out
end

function M.labelsMatching(labelList, input)
  local out = {}
  for _, label in ipairs(labelList) do
    if label:sub(1, #input) == input then
      table.insert(out, label)
    end
  end
  return out
end

local function newSession(gotoLine)
  return { phase = 'collecting', input = '', node = nil, timer = nil, gotoLine = gotoLine }
end

local function visibleLines(ctx)
  local total = text_.lineCount(ctx.port:getText())
  local visible = ctx.port:visibleLineRange()
  if visible == nil then
    return { first = 0, last = total - 1 }
  end
  return {
    first = math.min(math.max(visible.first, 0), total - 1),
    last = math.min(math.max(visible.last, 0), total - 1),
  }
end

local function matches(ctx, input)
  if #input == 0 then
    return {}
  end
  local text = ctx.port:getText()
  local vis = visibleLines(ctx)
  local from = text_.lineStart(text, vis.first)
  local to = text_.lineEnd(text, vis.last)
  local haystack = text:lower()
  local needle = input:lower()
  local out = {}
  local i = from
  while i <= to - #needle do
    if haystack:sub(i + 1, i + #needle) == needle then
      table.insert(out, i)
      i = i + #needle
    else
      i = i + 1
    end
  end
  return out
end

local function jump(ctx, offset)
  local sel = ctx.port:getSelections()[1]
  if sel.anchor ~= sel.active then
    ctx.port:setSelections({ { anchor = Sel.mark(ctx), active = offset } })
  else
    ctx.port:setSelections({ { anchor = offset, active = offset } })
  end
end

function M.cancel(ctx)
  local session = ctx.st.avy
  if session ~= nil then
    if session.timer ~= nil then
      ctx.ui:cancelTimer(session.timer)
    end
    session.timer = nil
    ctx.ui:clearAvy()
  end
  ctx.st.avy = nil
end

local function toSelecting(ctx, session, candidates)
  ctx.ui:clearAvy()
  session.phase = 'selecting'
  session.node = tree(candidates)
  ctx.ui:showAvyLabels(labels(session.node))
end

function M.finishInput(ctx)
  local session = ctx.st.avy
  if session == nil or session.phase ~= 'collecting' then
    return
  end
  if session.timer ~= nil then
    ctx.ui:cancelTimer(session.timer)
  end
  session.timer = nil
  local candidates = matches(ctx, session.input)
  if #candidates == 0 then
    M.cancel(ctx)
    ctx.ui:hint('zero candidates')
  elseif #candidates == 1 then
    M.cancel(ctx)
    jump(ctx, candidates[1])
  else
    toSelecting(ctx, session, candidates)
  end
end

local function collect(ctx, session, c)
  session.input = session.input .. c
  if session.timer ~= nil then
    ctx.ui:cancelTimer(session.timer)
  end
  session.timer = ctx.ui:startTimer(M.TIMEOUT_MS, function()
    M.finishInput(ctx)
  end)
  local len = #session.input
  local ranges = {}
  for _, start in ipairs(matches(ctx, session.input)) do
    table.insert(ranges, { start = start, stop = start + len })
  end
  ctx.ui:showAvyMatches(ranges)
end

local function selectLabel(ctx, session, c)
  if session.gotoLine and c >= '0' and c <= '9' then
    M.cancel(ctx)
    local input = ctx.ui:input('Goto line:', c)
    if input == nil then
      return
    end
    local text = ctx.port:getText()
    local ln = text_.parsedLineNumber(input, text_.lineCount(text))
    if ln == nil then
      return
    end
    jump(ctx, text_.lineStart(text, ln))
    return
  end
  local node = session.node
  if node == nil then
    return
  end
  local child = nil
  for _, pair in ipairs(node.children) do
    if pair[1] == c then
      child = pair[2]
      break
    end
  end
  if child == nil then
    ctx.ui:hint('No such candidate: ' .. c)
  elseif child.kind == 'leaf' then
    M.cancel(ctx)
    jump(ctx, child.offset)
  else
    session.node = child
    ctx.ui:showAvyLabels(labels(child))
  end
end

function M.key(ctx, c)
  local session = ctx.st.avy
  if session == nil then
    return
  end
  if session.phase == 'collecting' then
    collect(ctx, session, c)
  else
    selectLabel(ctx, session, c)
  end
end

local function startCharTimer(ctx)
  M.cancel(ctx)
  ctx.st.avy = newSession(false)
end

local function startGotoLine(ctx)
  M.cancel(ctx)
  local session = newSession(true)
  ctx.st.avy = session
  local text = ctx.port:getText()
  local vis = visibleLines(ctx)
  local candidates = {}
  for ln = vis.first, vis.last do
    table.insert(candidates, text_.lineStart(text, ln))
  end
  toSelecting(ctx, session, candidates)
end

M.commands = {
  ['avy-goto-char-timer'] = startCharTimer,
  ['avy-goto-line'] = startGotoLine,
}

return M
