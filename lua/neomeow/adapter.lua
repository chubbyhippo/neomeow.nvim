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
local Chord = require('neomeow.core.chord')
local Chords = require('neomeow.core.chords')
local Uimod = require('neomeow.ui')

local NVIM_KEY_NAMES = {
  [' '] = 'Space',
  ['\t'] = 'Tab',
  ['\\'] = 'Bslash',
  ['<'] = 'lt',
  ['|'] = 'Bar',
}

local M = {}

local contexts = {}

local function bufLines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function offsetToRC(buf, offset)
  local lines = bufLines(buf)
  local acc = 0
  for i, line in ipairs(lines) do
    if offset <= acc + #line then
      return i - 1, offset - acc
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
        local relativeStart, relativeEnd = re:match_str(text:sub(from + 1))
        if relativeStart == nil then
          break
        end
        local matchStart = from + relativeStart
        local matchEnd = from + relativeEnd
        if matchEnd == matchStart then
          from = matchStart + 1
        else
          table.insert(out, { start = matchStart, stop = matchEnd })
          from = matchEnd
        end
      end
      return out
    end,
    fullyMatches = function(pattern, text)
      local built, re = pcall(vim.regex, '\\%^\\%(' .. pattern .. '\\)\\%$')
      if not built then
        return false
      end
      return re:match_str(text) ~= nil
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
    for i, sel in ipairs(self.sels) do
      out[i] = { anchor = sel.anchor, active = sel.active }
    end
    return out
  end

  function port:setSelections(sels)
    local out = {}
    for i, sel in ipairs(sels) do
      out[i] = { anchor = sel.anchor, active = sel.active }
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
    for i, edit in ipairs(edits) do
      ordered[i] = edit
    end
    table.sort(ordered, function(a, b)
      return a.start > b.start
    end)
    for _, edit in ipairs(ordered) do
      local startRow, startCol = offsetToRC(buf, edit.start)
      local endRow, endCol = offsetToRC(buf, edit.stop)
      local parts = vim.split(edit.text, '\n', { plain = true })
      vim.api.nvim_buf_set_text(buf, startRow, startCol, endRow, endCol, parts)
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
  for digit = string.byte('0'), string.byte('9') do
    set[string.char(digit)] = true
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
  local offset = rcToOffset(buf, pos[1] - 1, pos[2])
  local sels = ctx.port:getSelections()
  local head = sels[1]
  if head.anchor == head.active then
    ctx.port.sels[1] = { anchor = offset, active = offset }
  else
    ctx.port.sels[1] = { anchor = head.anchor, active = offset }
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

local function nvimChordKey(spelling)
  local chord = Chord.parse(spelling)
  if chord == nil then
    return nil
  end
  local name = NVIM_KEY_NAMES[chord.key] or chord.key
  local prefix = (chord.ctrl and 'C-' or '') .. (chord.alt and 'M-' or '') .. (chord.shift and 'S-' or '')
  return '<' .. prefix .. name .. '>'
end

local function chordKeymaps()
  local _, order = Rc.chordBindings()
  local out = {}
  for _, spelling in ipairs(order) do
    local lhs = nvimChordKey(spelling)
    if lhs ~= nil then
      out[lhs] = spelling
    end
  end
  return out
end

local function setChordKeymaps(buf)
  for lhs, spelling in pairs(chordKeymaps()) do
    vim.keymap.set('n', lhs, function()
      local ctx = contexts[buf]
      if ctx == nil then
        return
      end
      syncCursorToState(ctx, buf)
      if not Chords.dispatch(ctx, Chord.parse(spelling)) then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
      end
    end, { buffer = buf, nowait = true, desc = 'neomeow chord ' .. spelling })
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

  local state = newState()
  local port = makePort(buf)
  local ctx
  local ui = Uimod.make(function()
    return ctx
  end, buf)
  ctx = { port = port, clipboard = makeClipboard(), ui = ui, rx = makeRx(), state = state }
  contexts[buf] = ctx

  vim.bo[buf].modifiable = attachpolicy.isWritableSurface(surface) and vim.bo[buf].modifiable
  vim.wo[vim.fn.bufwinid(buf) ~= -1 and vim.fn.bufwinid(buf) or 0].virtualedit = 'onemore'
  vim.b[buf].neomeow_mode = state.mode

  setNormalKeymaps(buf)
  setChordKeymaps(buf)

  vim.keymap.set('n', '<Esc>', function()
    Engine.escapeKey(ctx)
  end, { buffer = buf, nowait = true, desc = 'neomeow escape' })

  vim.keymap.set('i', '<M-;>', function()
    Engine.enterKeypad(ctx)
    vim.cmd('stopinsert')
  end, { buffer = buf, nowait = true, desc = 'neomeow keypad from INSERT' })

  local group = vim.api.nvim_create_augroup('neomeow-buf-' .. buf, { clear = true })
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    buffer = buf,
    callback = function()
      if state.mode == core.state.MeowMode.INSERT then
        state.mode = core.state.MeowMode.NORMAL
        ui:refresh(state)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    group = group,
    buffer = buf,
    callback = function()
      contexts[buf] = nil
    end,
  })

  ui:refresh(state)
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
      for lhs in pairs(chordKeymaps()) do
        pcall(vim.keymap.del, 'n', lhs, { buffer = buf })
      end
      setNormalKeymaps(buf)
      setChordKeymaps(buf)
    end
  end
end

return M
