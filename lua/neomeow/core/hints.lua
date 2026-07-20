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

local M = {}

function M.expandHintPositions(ctx, count)
  count = count == nil and 10 or count
  local text = ctx.port:getText()
  local sel = ctx.port:getSelections()[1]
  if sel.anchor == sel.active then
    return {}
  end
  local st = ctx.st
  local caret = sel.active
  local backward = caret < sel.anchor
  local out = {}
  if st.selType == SelType.WORD or st.selType == SelType.SYMBOL then
    local pred = text_.charPred(st.selType == SelType.SYMBOL)
    local i = caret
    for _ = 1, count do
      if backward then
        i = text_.Words.prevStart(text, i, 1, pred)
      else
        i = text_.Words.nextEnd(text, i, 1, pred)
      end
      if backward and i <= 0 then
        break
      end
      if not backward and i >= #text then
        break
      end
      table.insert(out, i)
    end
  elseif st.selType == SelType.LINE then
    local ln = text_.lineOfOffset(text, caret)
    for _ = 1, count do
      ln = ln + (backward and -1 or 1)
      if ln < 0 or ln > text_.lineCount(text) - 1 then
        break
      end
      table.insert(out, backward and text_.lineStart(text, ln) or text_.lineEnd(text, ln))
    end
  elseif st.selType == SelType.FIND or st.selType == SelType.TILL then
    local c = st.lastFind
    if c == nil then
      return out
    end
    local till = st.selType == SelType.TILL
    for k = 1, count do
      local t = text_.nthCharTarget(text, c, caret, k, backward, till)
      if t < 0 then
        break
      end
      table.insert(out, t)
    end
  end
  local seen = {}
  local unique = {}
  for _, p in ipairs(out) do
    if not seen[p] then
      seen[p] = true
      table.insert(unique, p)
    end
  end
  return unique
end

return M
