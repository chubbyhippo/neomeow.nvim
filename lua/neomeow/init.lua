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
local Rc = core.rc
local adapter = require('neomeow.adapter')
local windmove = require('neomeow.core.windmove')
local ace = require('neomeow.core.acewindow')
local resize = require('neomeow.core.resize')
local toolWindowEscape = require('neomeow.core.toolwindowescape')

local ESC = '\27'
local ACE_LABEL_ZINDEX = 300

local lastEditorWindow = nil

local M = {}

local function surfaceOf(buf)
  local buftype = vim.bo[buf].buftype
  return buftype == '' and 'file-editor' or buftype
end

local function isToolWindow(buf)
  return core.attachpolicy.attachMode(surfaceOf(buf)) == nil
end

local function escapeFromToolWindow()
  local win = vim.api.nvim_get_current_win()
  local surface = surfaceOf(vim.api.nvim_get_current_buf()) .. '@' .. tostring(win)
  if not toolWindowEscape.onEscape(surface, vim.uv.now()) then
    return
  end
  if lastEditorWindow ~= nil and vim.api.nvim_win_is_valid(lastEditorWindow) then
    vim.api.nvim_set_current_win(lastEditorWindow)
  end
end

local function bundledRcLines()
  return vim.split(require('neomeow.default_rc'), '\n', { plain = true })
end

local function settingsPath()
  return vim.fn.stdpath('config') .. '/' .. Rc.USER_FILE_NAME
end

local function loadUserLines()
  local path = settingsPath()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, mod = pcall(dofile, path)
  if not ok or type(mod) ~= 'table' or type(mod.rc) ~= 'table' then
    return {}
  end
  return mod.rc
end

local SEED = [[
-- neomeow.lua — your personal meow layer for Neovim.
-- Return { rc = { <lines> } }: each string is one .neomeowrc line and
-- overrides the bundled default entry by entry. The full default layout is
-- already active; only what you list here changes. Reload with SPC c M.
--
-- Syntax:
--   'nmap <key> <action>(excommand)'   NORMAL key -> :excommand
--   'nmap <key> meow-command'          NORMAL key -> a named meow command
--   'nmap <key> <meow keys>'           NORMAL key -> replayed meow keys
--   'mmap <key> <target>'              MOTION mode (list-like buffers)
--   'map <leader><seq> <target>'       keypad (SPC) entry
--   'desc <leader><seq> text'          which-key label
--   'set timeoutlen=300'  /  'set nowhich-key'
--   'set overlay-color=#RRGGBB'         avy/ace label background
--   'set overlay-text-color=#RRGGBB'    avy/ace label text
--   'set expand-hint-color=#RRGGBB'     0-9 expand-hint badge
--   'set grab-color=#RRGGBB'            grab / beacon highlight
--   'repeat <group> <key> <target>'    tap-to-continue run
return {
  rc = {
    -- 'nmap S avy-goto-char-timer',
    -- 'map <leader>ff <action>(Telescope find_files)',
    -- 'desc <leader>f find',
  },
}
]]

local function windmoveStep(dir)
  local before = vim.api.nvim_get_current_win()
  vim.cmd(windmove.plan(dir))
  if vim.api.nvim_get_current_win() == before then
    vim.api.nvim_echo({ { windmove.noWindowMessage(dir), 'WarningMsg' } }, false, {})
  end
end

local function windmoveSwap(dir)
  local w1 = vim.api.nvim_get_current_win()
  local b1 = vim.api.nvim_win_get_buf(w1)
  vim.cmd(windmove.plan(dir))
  local w2 = vim.api.nvim_get_current_win()
  if w2 == w1 then
    vim.api.nvim_echo({ { windmove.noWindowMessage(dir), 'WarningMsg' } }, false, {})
    return
  end
  local b2 = vim.api.nvim_win_get_buf(w2)
  vim.api.nvim_win_set_buf(w1, b2)
  vim.api.nvim_win_set_buf(w2, b1)
end

local function aceCandidates()
  local out = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      local pos = vim.api.nvim_win_get_position(win)
      table.insert(out, { item = win, x = pos[2], y = pos[1] })
    end
  end
  return out
end

local function paintAceLabels(wins, labelList)
  local floats = {}
  for i, win in ipairs(wins) do
    local label = labelList[i]
    if label ~= nil and vim.api.nvim_win_is_valid(win) then
      local scratch = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { ' ' .. label .. ' ' })
      vim.bo[scratch].bufhidden = 'wipe'
      local pos = vim.api.nvim_win_get_position(win)
      local float = vim.api.nvim_open_win(scratch, false, {
        relative = 'editor',
        row = pos[1],
        col = pos[2],
        width = #label + 2,
        height = 1,
        style = 'minimal',
        focusable = false,
        noautocmd = true,
        zindex = ACE_LABEL_ZINDEX,
      })
      vim.wo[float].winhighlight = 'Normal:NeomeowAvyLead'
      table.insert(floats, float)
    end
  end
  return floats
end

local function clearAceLabels(floats)
  for _, float in ipairs(floats) do
    if vim.api.nvim_win_is_valid(float) then
      vim.api.nvim_win_close(float, true)
    end
  end
end

local function windowLabelled(wins, labelList, label)
  for i, candidate in ipairs(labelList) do
    if candidate == label then
      return wins[i]
    end
  end
  return nil
end

local function readAcePick(wins, labelList)
  local floats = paintAceLabels(wins, labelList)
  vim.cmd('redraw')
  local input = ''
  local picked = nil
  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok or ch == '' or ch == ESC then
      break
    end
    input = input .. ch
    local remaining = ace.matches(labelList, input)
    if #remaining == 0 then
      break
    end
    if #remaining == 1 and remaining[1] == input then
      picked = windowLabelled(wins, labelList, input)
      break
    end
  end
  clearAceLabels(floats)
  return picked
end

local function otherWindow(wins)
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(wins) do
    if win ~= current then
      return win
    end
  end
  return nil
end

local function aceTarget()
  local wins = ace.ordered(aceCandidates())
  local plan = ace.plan(#wins)
  if plan == ace.Plan.None then
    vim.api.nvim_echo({ { windmove.noWindowMessage('other'), 'WarningMsg' } }, false, {})
    return nil
  end
  if plan == ace.Plan.Other then
    return otherWindow(wins)
  end
  return readAcePick(wins, ace.labels(#wins))
end

function M.aceWindow()
  local target = aceTarget()
  if target == nil or not vim.api.nvim_win_is_valid(target) then
    return
  end
  vim.api.nvim_set_current_win(target)
end

function M.aceSwapWindow()
  local from = vim.api.nvim_get_current_win()
  local target = aceTarget()
  if target == nil or target == from or not vim.api.nvim_win_is_valid(target) then
    return
  end
  local here = vim.api.nvim_win_get_buf(from)
  local there = vim.api.nvim_win_get_buf(target)
  vim.api.nvim_win_set_buf(from, there)
  vim.api.nvim_win_set_buf(target, here)
  vim.api.nvim_set_current_win(target)
end

function M.aceResize()
  local keys = resize.keys()
  if #keys == 0 then
    vim.api.nvim_echo({ { 'neomeow: no resize keys in the rc', 'WarningMsg' } }, false, {})
    return
  end
  local ctx = adapter.contextFor(vim.api.nvim_get_current_buf())
  if ctx == nil then
    return
  end
  local prompt = 'resize: ' .. table.concat(keys, ' ') .. ' — ESC when done'
  while true do
    vim.api.nvim_echo({ { 'neomeow: ' .. prompt, 'Normal' } }, false, {})
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok or ch == '' or ch == ESC then
      break
    end
    if not resize.dispatch(ctx, ch) then
      break
    end
    vim.cmd('redraw')
  end
  vim.api.nvim_echo({ { '', 'Normal' } }, false, {})
end

function M.editRc()
  local path = settingsPath()
  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    local f = io.open(path, 'w')
    if f ~= nil then
      f:write(SEED)
      f:close()
    end
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
end

function M.reloadRc()
  adapter.reloadUserRc(loadUserLines())
  vim.api.nvim_echo({ { 'neomeow: reloaded ' .. Rc.USER_FILE_NAME, 'Normal' } }, false, {})
end

function M.statusline()
  local st = vim.b.neomeow_mode
  if st == nil then
    return ''
  end
  return 'MEOW ' .. st
end

local function registerCommands()
  local dirs = { Left = 'left', Right = 'right', Up = 'up', Down = 'down' }
  for suffix, dir in pairs(dirs) do
    vim.api.nvim_create_user_command('NeomeowWindmove' .. suffix, function()
      windmoveStep(dir)
    end, {})
    vim.api.nvim_create_user_command('NeomeowWindmoveSwap' .. suffix, function()
      windmoveSwap(dir)
    end, {})
  end
  vim.api.nvim_create_user_command('NeomeowAceWindow', function()
    M.aceWindow()
  end, {})
  vim.api.nvim_create_user_command('NeomeowAceSwapWindow', function()
    M.aceSwapWindow()
  end, {})
  vim.api.nvim_create_user_command('NeomeowAceResize', function()
    M.aceResize()
  end, {})
  vim.api.nvim_create_user_command('NeomeowEditRc', function()
    M.editRc()
  end, {})
  vim.api.nvim_create_user_command('NeomeowReloadRc', function()
    M.reloadRc()
  end, {})
end

function M.setup(opts)
  opts = opts or {}
  Rc.initDefaults(bundledRcLines())
  if type(opts.rc) == 'table' then
    Rc.setUserLines(opts.rc)
  else
    Rc.setUserLines(loadUserLines())
  end
  registerCommands()

  local grp = vim.api.nvim_create_augroup('neomeow', { clear = true })
  local filetypes = opts.filetypes
  vim.api.nvim_create_autocmd(filetypes ~= nil and 'FileType' or 'BufEnter', {
    group = grp,
    pattern = filetypes,
    callback = function(ev)
      adapter.attach(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'TermOpen' }, {
    group = grp,
    callback = function(ev)
      if not isToolWindow(ev.buf) then
        return
      end
      vim.keymap.set('n', '<Esc>', escapeFromToolWindow, {
        buffer = ev.buf,
        nowait = true,
        desc = 'neomeow tool-window escape',
      })
    end,
  })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = grp,
    callback = function(ev)
      if isToolWindow(ev.buf) then
        return
      end
      toolWindowEscape.reset()
      lastEditorWindow = vim.api.nvim_get_current_win()
    end,
  })
end

M.attach = adapter.attach

return M
