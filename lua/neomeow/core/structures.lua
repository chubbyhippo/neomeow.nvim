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
local Things = require('neomeow.core.things').Things
local Sel = require('neomeow.core.selections')

local M = {}

local function pendThing(ctx, p)
  ctx.st.pending = p
  ctx.ui:scheduleWhichKey('things', '')
end

function M.thingSelect(ctx, kind, ch)
  local off = Sel.primary(ctx).active
  local b
  if kind == Pending.BOUNDS then
    b = Things.bounds(ctx, ch, off)
  else
    b = Things.inner(ctx, ch, off)
  end
  if b == nil then
    ctx.ui:hint("No thing '" .. ch .. "' here")
    return
  end
  if kind == Pending.INNER then
    Sel.select(ctx, SelType.TRANSIENT, b.start, b.stop, false)
  elseif kind == Pending.BOUNDS then
    Sel.select(ctx, SelType.TRANSIENT, b.stop, b.start, false)
  elseif kind == Pending.BEGIN then
    Sel.select(ctx, SelType.TRANSIENT, off, b.start, false)
  elseif kind == Pending.END_ then
    Sel.select(ctx, SelType.TRANSIENT, off, b.stop, false)
  end
end

local function enclosingPair(text, s, e)
  local opens = '([{'
  local closes = ')]}'
  local stack = {}
  local best = nil
  local i = 0
  while i < #text do
    local c = text_.charAt(text, i)
    if c == '"' or c == "'" or c == '`' then
      local j = i + 1
      while j < #text and text_.charAt(text, j) ~= c and text_.charAt(text, j) ~= '\n' do
        if text_.charAt(text, j) == '\\' then
          j = j + 1
        end
        j = j + 1
      end
      if j < #text and text_.charAt(text, j) == c then
        i = j + 1
      else
        i = i + 1
      end
    else
      if opens:find(c, 1, true) ~= nil then
        table.insert(stack, i)
      elseif closes:find(c, 1, true) ~= nil then
        local kind = closes:find(c, 1, true)
        while #stack > 0 do
          local o = table.remove(stack)
          if opens:find(text_.charAt(text, o), 1, true) == kind then
            if o < s and i + 1 >= e and (best == nil or i - o < best.close - best.open) then
              best = { open = o, close = i }
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
  local active = ctx.st.selType == SelType.BLOCK and Sel.hasSelection(sel)
  local back = Sel.backwardP(ctx) ~= (ctx.st:takeCount(1) < 0)
  local s = active and math.min(sel.anchor, sel.active) or sel.active
  local e = active and math.max(sel.anchor, sel.active) or sel.active
  local p = enclosingPair(text, s, e)
  if p == nil then
    ctx.ui:hint('No enclosing block')
    return
  end
  if back then
    Sel.select(ctx, SelType.BLOCK, p.close + 1, p.open, true)
  else
    Sel.select(ctx, SelType.BLOCK, p.open, p.close + 1, true)
  end
end

local function toBlock(ctx)
  local text = ctx.port:getText()
  local back = (ctx.st.selType == SelType.BLOCK and Sel.backwardP(ctx)) or ctx.st:takeCount(1) < 0
  local caret = Sel.primary(ctx).active
  local p = enclosingPair(text, caret, caret)
  if p == nil then
    ctx.ui:hint('No enclosing block')
    return
  end
  Sel.select(ctx, SelType.BLOCK, caret, back and p.open or (p.close + 1), true)
end

local function join(ctx)
  local text = ctx.port:getText()
  if #text == 0 then
    return
  end
  local n = ctx.st:takeCount(1)
  local function blank(l)
    return text_.isBlankLine(text, l)
  end
  local ln = text_.lineOfOffset(text, Sel.primary(ctx).active)
  if n >= 0 then
    local pl = ln - 1
    while pl >= 0 and blank(pl) do
      pl = pl - 1
    end
    if pl < 0 then
      return
    end
    local m = text_.lineEnd(text, pl)
    local p = text_.lineStart(text, ln)
    local eol = text_.lineEnd(text, ln)
    while p < eol and text_.charAt(text, p):match('^%s$') ~= nil do
      p = p + 1
    end
    Sel.select(ctx, SelType.JOIN, m, p, true)
  else
    local last = text_.lineCount(text) - 1
    local nl = ln + 1
    while nl <= last and blank(nl) do
      nl = nl + 1
    end
    if nl > last then
      return
    end
    local m = text_.lineEnd(text, ln)
    local p = text_.lineStart(text, nl)
    local eol = text_.lineEnd(text, nl)
    while p < eol and text_.charAt(text, p):match('^%s$') ~= nil do
      p = p + 1
    end
    Sel.select(ctx, SelType.JOIN, m, p, true)
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
