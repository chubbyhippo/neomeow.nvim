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
local whichkey = require('neomeow.core.whichkey')
local Sel = require('neomeow.core.selections')
local MeowMode = require('neomeow.core.state').MeowMode

local ns = vim.api.nvim_create_namespace('neomeow')

local M = {}

local function setHighlights()
  local function ensure(name, opts)
    if vim.fn.hlexists(name) == 0 or next(vim.api.nvim_get_hl(0, { name = name })) == nil then
      vim.api.nvim_set_hl(0, name, opts)
    end
  end
  ensure('NeomeowSelection', { link = 'Visual', default = true })
  local grab = Rc.grabColor()
  if grab ~= nil then
    ensure('NeomeowGrab', { bg = grab, default = true })
  else
    ensure('NeomeowGrab', { link = 'DiffAdd', default = true })
  end
  ensure('NeomeowMatch', { link = 'Search', default = true })
  ensure('NeomeowAvyLead', { fg = Rc.overlayTextColor(), bg = Rc.overlayColor(), bold = true, default = true })
  ensure('NeomeowHint', { fg = '#ffffff', bg = Rc.expandHintColor(), bold = true, default = true })
end

local function offsetToRC(buf, off)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local acc = 0
  for i, line in ipairs(lines) do
    if off <= acc + #line then
      return i - 1, off - acc
    end
    acc = acc + #line + 1
  end
  local last = #lines
  return last - 1, #(lines[last] or '')
end

function M.make(getCtx, buf)
  local ui = {}
  local timers = {}
  local timerSeq = 0
  local whichKeyWin = nil
  local whichKeyShown = false
  local whichKeyTimer = nil

  local function clearNs()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end

  local function markRange(range, hl)
    if range == nil or range.stop <= range.start then
      return
    end
    local sr, sc = offsetToRC(buf, range.start)
    local er, ec = offsetToRC(buf, range.stop)
    vim.api.nvim_buf_set_extmark(buf, ns, sr, sc, {
      end_row = er,
      end_col = ec,
      hl_group = hl,
      priority = 200,
    })
  end

  local grabRange = nil

  local function repaintSelection()
    clearNs()
    markRange(grabRange, 'NeomeowGrab')
    local ctx = getCtx()
    for _, sel in ipairs(ctx.port:getSelections()) do
      local lo = Sel.lo(sel)
      local hi = Sel.hi(sel)
      markRange({ start = lo, stop = hi }, 'NeomeowSelection')
    end
  end

  function ui.hint(_, text)
    vim.api.nvim_echo({ { 'neomeow: ' .. text, 'WarningMsg' } }, false, {})
  end

  function ui.info(_, title, body)
    local lines = { title, string.rep('-', #title) }
    for _, l in ipairs(vim.split(body, '\n', { plain = true })) do
      table.insert(lines, l)
    end
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
    vim.bo[scratch].modifiable = false
    vim.bo[scratch].bufhidden = 'wipe'
    local width = 0
    for _, l in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(l))
    end
    local height = math.min(#lines, vim.o.lines - 4)
    local fwin = vim.api.nvim_open_win(scratch, true, {
      relative = 'editor',
      width = math.min(width + 2, vim.o.columns - 4),
      height = height,
      row = math.max((vim.o.lines - height) / 2 - 1, 0),
      col = math.max((vim.o.columns - width) / 2 - 1, 0),
      style = 'minimal',
      border = 'rounded',
    })
    vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = scratch })
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = scratch })
    return fwin
  end

  function ui.input(_, prompt, initial)
    local ok, result =
      pcall(vim.fn.input, { prompt = (prompt or '') .. ' ', default = initial or '', cancelreturn = '\0' })
    if not ok or result == '\0' then
      return nil
    end
    return result
  end

  function ui.runCommand(_, id)
    vim.cmd(id)
  end

  function ui.hideWhichKey()
    if whichKeyTimer ~= nil then
      whichKeyTimer:stop()
      whichKeyTimer = nil
    end
    if whichKeyWin ~= nil and vim.api.nvim_win_is_valid(whichKeyWin) then
      vim.api.nvim_win_close(whichKeyWin, true)
    end
    whichKeyWin = nil
    whichKeyShown = false
  end

  local function drawWhichKey(kind, buffer)
    local rows
    if kind == 'things' then
      rows = whichkey.THINGS
    else
      rows = whichkey.keypadRows(buffer)
    end
    if #rows == 0 then
      return
    end
    local lines = {}
    for _, r in ipairs(rows) do
      table.insert(lines, string.format(' %s  %s', r[1], r[2]))
    end
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
    vim.bo[scratch].modifiable = false
    vim.bo[scratch].bufhidden = 'wipe'
    local width = 0
    for _, l in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(l))
    end
    if whichKeyWin ~= nil and vim.api.nvim_win_is_valid(whichKeyWin) then
      vim.api.nvim_win_close(whichKeyWin, true)
    end
    whichKeyWin = vim.api.nvim_open_win(scratch, false, {
      relative = 'editor',
      anchor = 'SW',
      width = math.min(width + 1, vim.o.columns - 2),
      height = math.min(#lines, 12),
      row = vim.o.lines - 2,
      col = 0,
      style = 'minimal',
      border = 'none',
      focusable = false,
      noautocmd = true,
    })
    whichKeyShown = true
  end

  function ui.scheduleWhichKey(_, kind, buffer)
    if not Rc.whichKeyEnabled() then
      return
    end
    if whichKeyTimer ~= nil then
      whichKeyTimer:stop()
      whichKeyTimer = nil
    end
    if whichKeyShown then
      drawWhichKey(kind, buffer)
      return
    end
    whichKeyTimer = vim.defer_fn(function()
      whichKeyTimer = nil
      drawWhichKey(kind, buffer)
    end, Rc.whichKeyDelayMs())
  end

  function ui.showExpandHints(_, positions)
    for i, off in ipairs(positions) do
      if i > 9 then
        break
      end
      local r, c = offsetToRC(buf, off)
      vim.api.nvim_buf_set_extmark(buf, ns, r, c, {
        virt_text = { { tostring(i), 'NeomeowHint' } },
        virt_text_pos = 'overlay',
        priority = 300,
      })
    end
  end

  function ui.clearExpandHints()
    repaintSelection()
  end

  function ui.showAvyMatches(_, ranges)
    clearNs()
    for _, range in ipairs(ranges) do
      markRange(range, 'NeomeowMatch')
    end
  end

  function ui.showAvyLabels(_, labels)
    clearNs()
    for _, pair in ipairs(labels) do
      local off, label = pair[1], pair[2]
      local r, c = offsetToRC(buf, off)
      vim.api.nvim_buf_set_extmark(buf, ns, r, c, {
        virt_text = { { label, 'NeomeowAvyLead' } },
        virt_text_pos = 'overlay',
        priority = 300,
      })
    end
  end

  function ui.clearAvy()
    repaintSelection()
  end

  function ui.setGrabHighlight(_, range)
    grabRange = range
    repaintSelection()
  end

  function ui.modeChanged(_, st)
    if st.mode == MeowMode.INSERT then
      if vim.api.nvim_get_mode().mode:sub(1, 1) ~= 'i' and vim.api.nvim_get_current_buf() == buf then
        vim.cmd('startinsert')
      end
    end
    vim.b[buf].neomeow_mode = st.mode
    vim.cmd('redrawstatus')
  end

  function ui.refresh(_, st)
    repaintSelection()
    vim.b[buf].neomeow_mode = st.mode
    vim.cmd('redrawstatus')
  end

  function ui.startTimer(_, ms, cb)
    timerSeq = timerSeq + 1
    local id = timerSeq
    timers[id] = vim.defer_fn(function()
      timers[id] = nil
      cb()
    end, ms)
    return id
  end

  function ui.cancelTimer(_, id)
    local t = timers[id]
    if t ~= nil then
      t:stop()
      timers[id] = nil
    end
  end

  setHighlights()
  return ui
end

return M
