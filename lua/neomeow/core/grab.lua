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
local SelType = require('neomeow.core.state').SelType
local Sel = require('neomeow.core.selections')

local M = {}

local MAX_GRAB_SYNC_MATCHES = 500

local function clear(ctx)
  ctx.st.grab = nil
  ctx.ui:setGrabHighlight(nil)
end

local function set(ctx, start, stop)
  ctx.st.grab = { start = start, stop = stop }
  if stop > start then
    ctx.ui:setGrabHighlight({ start = start, stop = stop })
  else
    ctx.ui:setGrabHighlight(nil)
  end
end

function M.adjustForEdits(st, edits)
  local g = st.grab
  if g == nil then
    return
  end
  local sorted = {}
  for i, e in ipairs(edits) do
    sorted[i] = e
  end
  table.sort(sorted, function(a, b)
    return a.start > b.start
  end)
  for _, e in ipairs(sorted) do
    local delta = #e.text - (e.stop - e.start)
    if g.start >= e.stop then
      g.start = g.start + delta
      g.stop = g.stop + delta
    else
      if g.stop >= e.stop then
        g.stop = g.stop + delta
      elseif g.stop > e.start then
        g.stop = e.start
      end
      if g.start > e.start then
        g.start = e.start
      end
    end
  end
  if g.stop < g.start then
    g.stop = g.start
  end
end

local function grab(ctx)
  clear(ctx)
  local sel = Sel.primary(ctx)
  if Sel.hasSelection(sel) then
    set(ctx, Sel.lo(sel), Sel.hi(sel))
  end
  Sel.cancel(ctx)
end

local function sync(ctx)
  local sel = Sel.primary(ctx)
  if not Sel.hasSelection(sel) then
    ctx.ui:hint('meow-sync-grab needs a selection')
    return
  end
  clear(ctx)
  set(ctx, Sel.lo(sel), Sel.hi(sel))
  Sel.cancel(ctx)
end

local function swap(ctx)
  if require('neomeow.core.edits').blockedReadOnly(ctx) then
    return
  end
  local port = ctx.port
  local st = ctx.st
  local g = st.grab
  local sel = Sel.primary(ctx)
  if g == nil then
    ctx.ui:hint('No grab')
    return
  end
  if not Sel.hasSelection(sel) then
    ctx.ui:hint('meow-swap-grab needs a selection')
    return
  end
  local gs = g.start
  local ge = g.stop
  local ss = Sel.lo(sel)
  local se = Sel.hi(sel)
  if math.max(gs, ss) < math.min(ge, se) and not (gs == ss and ge == se) then
    ctx.ui:hint('Selection overlaps the grab')
    return
  end
  local text = port:getText()
  local grabText = text_.slice(text, gs, ge)
  local selText = text_.slice(text, ss, se)
  st.grab = nil
  port:edit({
    { start = ss, stop = se, text = grabText },
    { start = gs, stop = ge, text = selText },
  })
  if gs <= ss then
    local delta = #selText - (ge - gs)
    set(ctx, gs, gs + #selText)
    local caret = ss + delta + #grabText
    port:setSelections({ { anchor = caret, active = caret } })
  else
    local delta = #grabText - (se - ss)
    set(ctx, gs + delta, gs + delta + #selText)
    local caret = ss + #grabText
    port:setSelections({ { anchor = caret, active = caret } })
  end
  st.selType = SelType.NONE
end

function M.pop(ctx)
  local g = ctx.st.grab
  if g == nil then
    return false
  end
  local start = g.start
  local stop = g.stop
  clear(ctx)
  Sel.select(ctx, SelType.TRANSIENT, start, stop, false)
  return true
end

function M.beacon(ctx)
  local port = ctx.port
  local st = ctx.st
  local g = st.grab
  if g == nil or g.stop <= g.start then
    return
  end
  local sel = Sel.primary(ctx)
  if not Sel.hasSelection(sel) then
    return
  end
  local ss = Sel.lo(sel)
  local se = Sel.hi(sel)
  if ss < g.start or se > g.stop or se == ss then
    return
  end
  local text = port:getText()
  local sels = {}
  if
    st.selType == SelType.WORD
    or st.selType == SelType.SYMBOL
    or st.selType == SelType.VISIT
    or st.selType == SelType.FIND
    or st.selType == SelType.TILL
    or st.selType == SelType.CHAR
  then
    local selText = text_.slice(text, ss, se)
    if selText:match('^%s*$') ~= nil then
      return
    end
    local bounded = st.selType == SelType.WORD or st.selType == SelType.SYMBOL
    local quoted = text_.regexQuote(selText)
    local pattern = bounded and ('\\<' .. quoted .. '\\>') or quoted
    local region = text_.slice(text, g.start, g.stop)
    local added = 0
    for _, m in ipairs(ctx.rx.allMatches(pattern, region)) do
      local s0 = g.start + m.start
      local e0 = g.start + m.stop
      if s0 ~= ss then
        table.insert(sels, { anchor = s0, active = e0 })
        added = added + 1
        if added >= MAX_GRAB_SYNC_MATCHES then
          break
        end
      end
    end
    if #sels == 0 then
      return
    end
    table.insert(sels, 1, { anchor = ss, active = se })
  elseif st.selType == SelType.LINE then
    local first = text_.lineOfOffset(text, g.start)
    local last = text_.lineOfOffset(text, math.max(g.stop - 1, g.start))
    if last <= first then
      return
    end
    for ln = first, last do
      table.insert(sels, { anchor = text_.lineStart(text, ln), active = text_.lineEnd(text, ln) })
    end
  else
    return
  end
  port:setSelections(sels)
end

M.commands = {
  ['meow-grab'] = grab,
  ['meow-sync-grab'] = sync,
  ['meow-swap-grab'] = swap,
}

return M
