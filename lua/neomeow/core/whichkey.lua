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

local Rc = require('neomeow.core.rc')

local M = {}

M.THINGS = {
  { 'r', 'round ( )' },
  { 's', 'square [ ]' },
  { 'c', 'curly { }' },
  { 'g', 'string' },
  { 'e', 'symbol' },
  { 'w', 'window' },
  { 'b', 'buffer' },
  { 'p', 'paragraph' },
  { 'l', 'line' },
  { 'v', 'visual line' },
  { 'd', 'defun' },
  { '.', 'sentence' },
}

function M.keypadRows(buffer)
  local descs = Rc.keypadDescs()
  local map, order = Rc.keypad()
  local rows = {}
  local rowOrder = {}
  for _, seq in ipairs(order) do
    if seq:sub(1, #buffer) == buffer and seq ~= buffer then
      local child = buffer .. seq:sub(#buffer + 1, #buffer + 1)
      local label
      if seq == child then
        label = descs[seq] or map[seq].action or map[seq].command or map[seq].keys or ''
      else
        label = descs[child] or '+more'
      end
      if rows[child] == nil then
        table.insert(rowOrder, child)
        rows[child] = label
      elseif descs[child] ~= nil then
        rows[child] = label
      end
    end
  end
  table.sort(rowOrder)
  local out = {}
  for _, child in ipairs(rowOrder) do
    local key = child:sub(-1)
    if key == ' ' then
      key = 'SPC'
    end
    table.insert(out, { key, rows[child] })
  end
  return out
end

return M
