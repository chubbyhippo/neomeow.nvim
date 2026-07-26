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

local core = require('neomeow.core')
local Engine = core.engine
local Rc = core.rc
local attachpolicy = core.attachpolicy
local newState = core.state.newState
local Uimod = require('neomeow.ui')

local M = {}

local contexts = {}

local function bufLines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function offsetToRC(buf, off)
  local lines = bufLines(buf)
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

local function rcToOffset(buf, row, col)
  local lines = bufLines(buf)
  local acc = 0
  for i = 1, row do
    acc = acc + #(lines[i] or '') + 1
  end
  return acc + col
end

local function makeRx()
  return {
    allMatches = function(pattern, text)
      local built, re = pcall(vim.regex, pattern)
      if not built then
        built, re = pcall(vim.regex, '\\V' .. vim.fn.escape(pattern, '\\'))
        if not built then
          return {}
        end
      end
      local out = {}
      local from = 0
      while from <= #text do
        local ms, me = re:match_str(text:sub(from + 1))
        if ms == nil then
          break
        end
        local s0 = from + ms
        local e0 = from + me
        if e0 == s0 then
          from = s0 + 1
        else
          table.insert(out, { start = s0, stop = e0 })
          from = e0
        end
      end
      return out
    end,
    fullyMatches = function(pattern, s)
      local built, re = pcall(vim.regex, '\\%^\\%(' .. pattern .. '\\)\\%$')
      if not built then
        return false
      end
      return re:match_str(s) ~= nil
    end,
    isValid = function(pattern)
      return (pcall(vim.regex, pattern))
    end,
  }
end

local function makePort(buf)
  local port = { sels = { { anchor = 0, active = 0 } } }

  function port.getText()
    return table.concat(bufLines(buf), '\n')
  end

  function port:getSelections()
    local out = {}
    for i, s in ipairs(self.sels) do
      out[i] = { anchor = s.anchor, active = s.active }
    end
    return out
  end

  function port:setSelections(sels)
    local out = {}
    for i, s in ipairs(sels) do
      out[i] = { anchor = s.anchor, active = s.active }
    end
    self.sels = out
    local active = out[1].active
    local row, col = offsetToRC(buf, active)
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      local lineLen = #(bufLines(buf)[row + 1] or '')
      vim.api.nvim_win_set_cursor(win, { row + 1, math.min(col, lineLen) })
    end
  end

  function port.edit(_, edits)
    local ordered = {}
    for i, e in ipairs(edits) do
      ordered[i] = e
    end
    table.sort(ordered, function(a, b)
      return a.start > b.start
    end)
    for _, e in ipairs(ordered) do
      local sr, sc = offsetToRC(buf, e.start)
      local er, ec = offsetToRC(buf, e.stop)
      local parts = vim.split(e.text, '\n', { plain = true })
      vim.api.nvim_buf_set_text(buf, sr, sc, er, ec, parts)
    end
  end

  function port.isWritable()
    return vim.bo[buf].modifiable and not vim.bo[buf].readonly
  end

  function port.visibleLineRange()
    local win = vim.fn.bufwinid(buf)
    if win == -1 then
      return nil
    end
    local first = vim.fn.line('w0', win) - 1
    local last = vim.fn.line('w$', win) - 1
    return { first = first, last = last }
  end

  function port.undo()
    vim.cmd('silent! undo')
  end

  function port.closeEditor()
    pcall(vim.cmd, 'close')
  end

  function port.symbolRangeAt()
    return nil
  end

  return port
end

local clipboardProvider = nil
local function hasClipboardProvider()
  if clipboardProvider == nil then
    local ok, exe = pcall(vim.fn['provider#clipboard#Executable'])
    clipboardProvider = ok and exe ~= nil and exe ~= ''
  end
  return clipboardProvider
end

local function makeClipboard()
  local fallback = nil
  return {
    read = function()
      if hasClipboardProvider() then
        local reg = vim.fn.getreg('+')
        if reg ~= nil and reg ~= '' then
          return reg
        end
      end
      return fallback
    end,
    write = function(_, text)
      fallback = text
      if hasClipboardProvider() then
        vim.fn.setreg('+', text)
      end
    end,
  }
end

local function boundKeys()
  local set = { [' '] = true }
  for k in pairs(Rc.defaults().normal) do
    set[k] = true
  end
  for k in pairs(Rc.cfg().normal) do
    set[k] = true
  end
  for c = string.byte('0'), string.byte('9') do
    set[string.char(c)] = true
  end
  set['-'] = true
  return set
end

local function syncCursorToState(ctx, buf)
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    return
  end
  local pos = vim.api.nvim_win_get_cursor(win)
  local off = rcToOffset(buf, pos[1] - 1, pos[2])
  local sels = ctx.port:getSelections()
  local head = sels[1]
  if head.anchor == head.active then
    ctx.port.sels[1] = { anchor = off, active = off }
  else
    ctx.port.sels[1] = { anchor = head.anchor, active = off }
  end
end

local function setNormalKeymaps(buf)
  for key in pairs(boundKeys()) do
    vim.keymap.set('n', key, function()
      local ctx = contexts[buf]
      syncCursorToState(ctx, buf)
      Engine.handleChar(ctx, key)
    end, { buffer = buf, nowait = true, desc = 'neomeow key' })
  end
end

function M.attach(buf)
  if contexts[buf] ~= nil then
    return contexts[buf]
  end
  local surface = vim.bo[buf].buftype == '' and 'file-editor' or vim.bo[buf].buftype
  local mode = attachpolicy.attachMode(surface)
  if mode == nil then
    return nil
  end

  local st = newState()
  local port = makePort(buf)
  local ctx
  local ui = Uimod.make(function()
    return ctx
  end, buf)
  ctx = { port = port, clipboard = makeClipboard(), ui = ui, rx = makeRx(), st = st }
  contexts[buf] = ctx

  vim.bo[buf].modifiable = attachpolicy.isWritableSurface(surface) and vim.bo[buf].modifiable
  vim.wo[vim.fn.bufwinid(buf) ~= -1 and vim.fn.bufwinid(buf) or 0].virtualedit = 'onemore'
  vim.b[buf].neomeow_mode = st.mode

  setNormalKeymaps(buf)

  vim.keymap.set('n', '<Esc>', function()
    Engine.escapeKey(ctx)
  end, { buffer = buf, nowait = true, desc = 'neomeow escape' })

  local grp = vim.api.nvim_create_augroup('neomeow-buf-' .. buf, { clear = true })
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = grp,
    buffer = buf,
    callback = function()
      if st.mode == core.state.MeowMode.INSERT then
        st.mode = core.state.MeowMode.NORMAL
        ui:refresh(st)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = grp,
    buffer = buf,
    callback = function()
      contexts[buf] = nil
    end,
  })

  ui:refresh(st)
  return ctx
end

function M.contextFor(buf)
  return contexts[buf]
end

function M.reloadUserRc(lines)
  Rc.setUserLines(lines)
  for buf in pairs(contexts) do
    if vim.api.nvim_buf_is_valid(buf) then
      for key in pairs(boundKeys()) do
        pcall(vim.keymap.del, 'n', key, { buffer = buf })
      end
      setNormalKeymaps(buf)
    end
  end
end

return M
