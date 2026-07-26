-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(root)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local failures = {}
local function check(name, cond)
  if cond then
    io.write('  ok   ' .. name .. '\n')
  else
    io.write('  FAIL ' .. name .. '\n')
    table.insert(failures, name)
  end
end

local neomeow = require('neomeow')
neomeow.setup({ rc = {} })

local function freshBuf(lines)
  vim.cmd('enew!')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = ''
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  neomeow.attach(buf)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  return buf
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'mx', false)
end

check('setup + attach produced a context', neomeow.attach(vim.api.nvim_get_current_buf()) ~= nil)

local buf = freshBuf({ 'hello world' })
feed('w')
local ctx = require('neomeow.adapter').contextFor(buf)
local sel = ctx.port:getSelections()[1]
check('w selects [0,5)', math.min(sel.anchor, sel.active) == 0 and math.max(sel.anchor, sel.active) == 5)

freshBuf({ 'hello' })
feed('l')
buf = vim.api.nvim_get_current_buf()
ctx = require('neomeow.adapter').contextFor(buf)
check('l moves caret to offset 1', ctx.port:getSelections()[1].active == 1)

buf = freshBuf({ 'abc' })
feed('iXY<Esc>')
check('typing in INSERT inserted text', vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'XYabc')
ctx = require('neomeow.adapter').contextFor(buf)
check('ESC returned to NORMAL', ctx.st.mode == 'NORMAL')

buf = freshBuf({ 'one two', 'three' })
feed('x')
ctx = require('neomeow.adapter').contextFor(buf)
sel = ctx.port:getSelections()[1]
check('x selects the line [0,7)', math.min(sel.anchor, sel.active) == 0 and math.max(sel.anchor, sel.active) == 7)

buf = freshBuf({ 'hello world' })
feed('ws')
check('w then s killed the word', vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ' world')
ctx = require('neomeow.adapter').contextFor(buf)
check('kill wrote the clipboard port', ctx.clipboard:read() == 'hello')

feed('p')
check('yank pasted the killed text', vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'hello world')

buf = freshBuf({ 'a', 'b', 'c', 'd' })
feed(' 2j')
ctx = require('neomeow.adapter').contextFor(buf)
check(
  'SPC 2 j moved to line index 2',
  require('neomeow.core.text').lineOfOffset(ctx.port:getText(), ctx.port:getSelections()[1].active) == 2
)

buf = freshBuf({ 'foo bar' })
feed('wcZAP<Esc>')
check('w then c replaced the word', vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == 'ZAP bar')

if #failures > 0 then
  io.write('SMOKE FAILED: ' .. #failures .. ' check(s)\n')
  vim.cmd('cquit 1')
else
  io.write('SMOKE OK\n')
  vim.cmd('quitall!')
end
