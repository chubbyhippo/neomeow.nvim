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

local M = {}

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
end

M.attach = adapter.attach

return M
