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
  ctx.state.grab = nil
  ctx.ui:setGrabHighlight(nil)
end

local function set(ctx, start, stop)
  ctx.state.grab = { start = start, stop = stop }
  if stop > start then
    ctx.ui:setGrabHighlight({ start = start, stop = stop })
  else
    ctx.ui:setGrabHighlight(nil)
  end
end

function M.adjustForEdits(state, edits)
  local grabbed = state.grab
  if grabbed == nil then
    return
  end
  local sorted = {}
  for i, edit in ipairs(edits) do
    sorted[i] = edit
  end
  table.sort(sorted, function(a, b)
    return a.start > b.start
  end)
  for _, edit in ipairs(sorted) do
    local delta = #edit.text - (edit.stop - edit.start)
    if grabbed.start >= edit.stop then
      grabbed.start = grabbed.start + delta
      grabbed.stop = grabbed.stop + delta
    else
      if grabbed.stop >= edit.stop then
        grabbed.stop = grabbed.stop + delta
      elseif grabbed.stop > edit.start then
        grabbed.stop = edit.start
      end
      if grabbed.start > edit.start then
        grabbed.start = edit.start
      end
    end
  end
  if grabbed.stop < grabbed.start then
    grabbed.stop = grabbed.start
  end
end

local function grab(ctx)
  clear(ctx)
  local sel = Sel.primary(ctx)
  if Sel.hasSelection(sel) then
    set(ctx, Sel.selStart(sel), Sel.selEnd(sel))
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
  set(ctx, Sel.selStart(sel), Sel.selEnd(sel))
  Sel.cancel(ctx)
end

local function swap(ctx)
  if require('neomeow.core.edits').blockedReadOnly(ctx) then
    return
  end
  local port = ctx.port
  local state = ctx.state
  local grabbed = state.grab
  local sel = Sel.primary(ctx)
  if grabbed == nil then
    ctx.ui:hint('No grab')
    return
  end
  if not Sel.hasSelection(sel) then
    ctx.ui:hint('meow-swap-grab needs a selection')
    return
  end
  local grabStart = grabbed.start
  local grabEnd = grabbed.stop
  local selStart = Sel.selStart(sel)
  local selEnd = Sel.selEnd(sel)
  local overlaps = math.max(grabStart, selStart) < math.min(grabEnd, selEnd)
  if overlaps and not (grabStart == selStart and grabEnd == selEnd) then
    ctx.ui:hint('Selection overlaps the grab')
    return
  end
  local text = port:getText()
  local grabText = text_.slice(text, grabStart, grabEnd)
  local selText = text_.slice(text, selStart, selEnd)
  state.grab = nil
  port:edit({
    { start = selStart, stop = selEnd, text = grabText },
    { start = grabStart, stop = grabEnd, text = selText },
  })
  if grabStart <= selStart then
    local delta = #selText - (grabEnd - grabStart)
    set(ctx, grabStart, grabStart + #selText)
    local caret = selStart + delta + #grabText
    port:setSelections({ { anchor = caret, active = caret } })
  else
    local delta = #grabText - (selEnd - selStart)
    set(ctx, grabStart + delta, grabStart + delta + #selText)
    local caret = selStart + #grabText
    port:setSelections({ { anchor = caret, active = caret } })
  end
  state.selType = SelType.NONE
end

function M.pop(ctx)
  local grabbed = ctx.state.grab
  if grabbed == nil then
    return false
  end
  local start = grabbed.start
  local stop = grabbed.stop
  clear(ctx)
  Sel.select(ctx, SelType.TRANSIENT, start, stop, false)
  return true
end

function M.beacon(ctx)
  local port = ctx.port
  local state = ctx.state
  local grabbed = state.grab
  if grabbed == nil or grabbed.stop <= grabbed.start then
    return
  end
  local sel = Sel.primary(ctx)
  if not Sel.hasSelection(sel) then
    return
  end
  local selStart = Sel.selStart(sel)
  local selEnd = Sel.selEnd(sel)
  if selStart < grabbed.start or selEnd > grabbed.stop or selEnd == selStart then
    return
  end
  local text = port:getText()
  local sels = {}
  if
    state.selType == SelType.WORD
    or state.selType == SelType.SYMBOL
    or state.selType == SelType.VISIT
    or state.selType == SelType.FIND
    or state.selType == SelType.TILL
    or state.selType == SelType.CHAR
  then
    local selText = text_.slice(text, selStart, selEnd)
    if selText:match('^%s*$') ~= nil then
      return
    end
    local bounded = state.selType == SelType.WORD or state.selType == SelType.SYMBOL
    local quoted = text_.regexQuote(selText)
    local pattern = bounded and ('\\<' .. quoted .. '\\>') or quoted
    local region = text_.slice(text, grabbed.start, grabbed.stop)
    local added = 0
    for _, match in ipairs(ctx.rx.allMatches(pattern, region)) do
      local matchStart = grabbed.start + match.start
      local matchEnd = grabbed.start + match.stop
      if matchStart ~= selStart then
        table.insert(sels, { anchor = matchStart, active = matchEnd })
        added = added + 1
        if added >= MAX_GRAB_SYNC_MATCHES then
          break
        end
      end
    end
    if #sels == 0 then
      return
    end
    table.insert(sels, 1, { anchor = selStart, active = selEnd })
  elseif state.selType == SelType.LINE then
    local first = text_.lineOfOffset(text, grabbed.start)
    local last = text_.lineOfOffset(text, math.max(grabbed.stop - 1, grabbed.start))
    if last <= first then
      return
    end
    for line = first, last do
      table.insert(sels, { anchor = text_.lineStart(text, line), active = text_.lineEnd(text, line) })
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
