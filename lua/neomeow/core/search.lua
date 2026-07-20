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

local SEARCH_RING_LIMIT = 50

function M.push(st, pattern)
  local kept = {}
  for _, p in ipairs(st.searchHistory) do
    if p ~= pattern then
      table.insert(kept, p)
    end
  end
  table.insert(kept, pattern)
  while #kept > SEARCH_RING_LIMIT do
    table.remove(kept, 1)
  end
  st.searchHistory = kept
end

local function searchWith(ctx, pattern, backward)
  local text = ctx.port:getText()
  local caret = Sel.primary(ctx).active
  local matches = ctx.rx.allMatches(pattern, text)
  local m
  if not backward then
    for _, x in ipairs(matches) do
      if x.start >= caret then
        m = x
        break
      end
    end
    if m == nil then
      m = matches[1]
    end
  else
    for _, x in ipairs(matches) do
      if x.stop <= caret then
        m = x
      end
    end
    if m == nil then
      m = matches[#matches]
    end
  end
  if m == nil then
    ctx.ui:hint('No match: ' .. pattern)
    return
  end
  if not backward then
    Sel.select(ctx, SelType.VISIT, m.start, m.stop, false)
  else
    Sel.select(ctx, SelType.VISIT, m.stop, m.start, false)
  end
end

local function search(ctx)
  local st = ctx.st
  local sel = Sel.primary(ctx)
  local pattern = st.searchHistory[#st.searchHistory]
  if Sel.hasSelection(sel) then
    local selText = text_.slice(ctx.port:getText(), math.min(sel.anchor, sel.active), math.max(sel.anchor, sel.active))
    if #selText > 0 and (pattern == nil or not ctx.rx.fullyMatches(pattern, selText)) then
      pattern = text_.regexQuote(selText)
      M.push(st, pattern)
    end
  end
  if pattern == nil then
    ctx.ui:hint('No search pattern')
    return
  end
  searchWith(ctx, pattern, st:takeCount(1) < 0 or Sel.backwardP(ctx))
end

local function visit(ctx)
  local backward = ctx.st:takeCount(1) < 0
  local input = ctx.ui:input('Visit (regexp):')
  if input == nil or input == '' then
    return
  end
  local pattern = input
  if not ctx.rx.isValid(pattern) then
    pattern = text_.regexQuote(input)
  end
  M.push(ctx.st, pattern)
  searchWith(ctx, pattern, backward)
end

M.commands = {
  ['meow-search'] = search,
  ['meow-visit'] = visit,
}

return M
