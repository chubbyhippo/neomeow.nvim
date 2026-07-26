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
local state = require('neomeow.core.state')
local MeowMode = state.MeowMode
local SelType = state.SelType
local port_ = require('neomeow.core.port')
local Sel = require('neomeow.core.selections')
local Grab = require('neomeow.core.grab')

local M = {}

local function allowModify(ctx)
  return ctx.port:isWritable()
end

function M.blockedReadOnly(ctx)
  if allowModify(ctx) then
    return false
  end
  ctx.ui:hint('Buffer is read-only')
  return true
end

local function editCarets(ctx, compute)
  local sels = ctx.port:getSelections()
  local order = {}
  for index, sel in ipairs(sels) do
    table.insert(order, { sel = sel, index = index, lo = Sel.lo(sel) })
  end
  table.sort(order, function(a, b)
    if a.lo ~= b.lo then
      return a.lo > b.lo
    end
    return a.index < b.index
  end)
  local edits = {}
  local results = {}
  for _, item in ipairs(order) do
    local hi = Sel.hi(item.sel)
    local r = compute(item.sel, item.lo, hi)
    if r.edit ~= nil then
      table.insert(edits, r.edit)
    end
    results[item.index] = r
  end
  local newSels = {}
  local delta = 0
  for i = #order, 1, -1 do
    local item = order[i]
    local r = results[item.index]
    newSels[item.index] = { anchor = r.sel.anchor + delta, active = r.sel.active + delta }
    if r.edit ~= nil then
      delta = delta + #r.edit.text - (r.edit.stop - r.edit.start)
    end
  end
  Grab.adjustForEdits(ctx.st, edits)
  if #edits > 0 then
    ctx.port:edit(edits)
  end
  ctx.port:setSelections(newSels)
end

local function deleteSelectionOrCharForward(text, lo, hi)
  if lo ~= hi then
    return { edit = { start = lo, stop = hi, text = '' }, sel = { anchor = lo, active = lo } }
  end
  if lo < #text then
    return { edit = { start = lo, stop = lo + 1, text = '' }, sel = { anchor = lo, active = lo } }
  end
  return { edit = nil, sel = { anchor = lo, active = lo } }
end

local function insert(ctx)
  local moved = {}
  for i, s in ipairs(ctx.port:getSelections()) do
    local o = Sel.lo(s)
    moved[i] = { anchor = o, active = o }
  end
  ctx.port:setSelections(moved)
  ctx.st.selType = SelType.NONE
  Sel.resetSelectionMemory(ctx.st)
  port_.setMode(ctx, MeowMode.INSERT)
end

local function append(ctx)
  local moved = {}
  for i, s in ipairs(ctx.port:getSelections()) do
    local o = Sel.hi(s)
    moved[i] = { anchor = o, active = o }
  end
  ctx.port:setSelections(moved)
  ctx.st.selType = SelType.NONE
  Sel.resetSelectionMemory(ctx.st)
  port_.setMode(ctx, MeowMode.INSERT)
end

local function openBelow(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local text = ctx.port:getText()
  local eol = text_.lineEnd(text, text_.lineOfOffset(text, Sel.primary(ctx).active))
  local edits = { { start = eol, stop = eol, text = '\n' } }
  Grab.adjustForEdits(ctx.st, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = eol + 1, active = eol + 1 } })
  port_.setMode(ctx, MeowMode.INSERT)
end

local function openLine(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local at = Sel.primary(ctx).active
  local edits = { { start = at, stop = at, text = '\n' } }
  Grab.adjustForEdits(ctx.st, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = at, active = at } })
end

local function horizontalSpace(ctx, replacement)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local text = ctx.port:getText()
  local at = Sel.primary(ctx).active
  local from = at
  while from > 0 and text_.isBlank(text:sub(from, from)) do
    from = from - 1
  end
  local to = at
  while to < #text and text_.isBlank(text:sub(to + 1, to + 1)) do
    to = to + 1
  end
  if from == to and replacement == '' then
    return
  end
  local edits = { { start = from, stop = to, text = replacement } }
  Grab.adjustForEdits(ctx.st, edits)
  ctx.port:edit(edits)
  local caret = from + #replacement
  ctx.port:setSelections({ { anchor = caret, active = caret } })
end

local function openAbove(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  Sel.collapse(ctx)
  local text = ctx.port:getText()
  local bol = text_.lineStart(text, text_.lineOfOffset(text, Sel.primary(ctx).active))
  local edits = { { start = bol, stop = bol, text = '\n' } }
  Grab.adjustForEdits(ctx.st, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = bol, active = bol } })
  port_.setMode(ctx, MeowMode.INSERT)
end

local function change(ctx)
  if not allowModify(ctx) then
    return
  end
  local text = ctx.port:getText()
  local prim = Sel.primary(ctx)
  if not Sel.hasSelection(prim) and prim.active >= #text then
    return
  end
  editCarets(ctx, function(_sel, lo, hi)
    return deleteSelectionOrCharForward(text, lo, hi)
  end)
  ctx.st.selType = SelType.NONE
  port_.setMode(ctx, MeowMode.INSERT)
end

local function del(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  local text = ctx.port:getText()
  editCarets(ctx, function(_sel, lo, hi)
    return deleteSelectionOrCharForward(text, lo, hi)
  end)
  ctx.st.selType = SelType.NONE
end

local function backwardDelete(ctx)
  if not allowModify(ctx) then
    return
  end
  editCarets(ctx, function(_sel, lo, hi)
    if lo ~= hi then
      return { edit = { start = lo, stop = hi, text = '' }, sel = { anchor = lo, active = lo } }
    end
    if lo > 0 then
      return { edit = { start = lo - 1, stop = lo, text = '' }, sel = { anchor = lo - 1, active = lo - 1 } }
    end
    return { edit = nil, sel = { anchor = lo, active = lo } }
  end)
  ctx.st.selType = SelType.NONE
end

local function killRange(ctx, sel, text)
  local lo = Sel.lo(sel)
  local hi = Sel.hi(sel)
  if ctx.st.selType == SelType.LINE and sel.active >= sel.anchor and hi < #text then
    if text_.charAt(text, hi) == '\r' then
      hi = hi + 1
    end
    if hi < #text and text_.charAt(text, hi) == '\n' then
      hi = hi + 1
    end
  end
  return { lo = lo, hi = hi }
end

local function regionsInOrder(sels)
  local regions = {}
  for _, s in ipairs(sels) do
    if s.anchor ~= s.active then
      table.insert(regions, s)
    end
  end
  table.sort(regions, function(a, b)
    return Sel.lo(a) < Sel.lo(b)
  end)
  return regions
end

local function joinedKillText(ctx, text, regions)
  local parts = {}
  for _, s in ipairs(regions) do
    local r = killRange(ctx, s, text)
    table.insert(parts, text_.slice(text, r.lo, r.hi))
  end
  return table.concat(parts, '\n')
end

local function joinKill(ctx)
  local text = ctx.port:getText()
  local prim = Sel.primary(ctx)
  local s = Sel.lo(prim)
  local e = Sel.hi(prim)
  local before = s > 0 and text_.charAt(text, s - 1) or '\n'
  local after = e < #text and text_.charAt(text, e) or '\n'
  local space = before ~= '\n'
    and after ~= '\n'
    and before:match('^%s$') == nil
    and after:match('^%s$') == nil
    and (')]}.,;:'):find(after, 1, true) == nil
    and ('([{'):find(before, 1, true) == nil
  local edits = { { start = s, stop = e, text = space and ' ' or '' } }
  Grab.adjustForEdits(ctx.st, edits)
  ctx.port:edit(edits)
  ctx.port:setSelections({ { anchor = s, active = s } })
  ctx.st.selType = SelType.NONE
  ctx.st.selExpand = false
end

local function kill(ctx)
  if not allowModify(ctx) then
    return
  end
  local st = ctx.st
  local text = ctx.port:getText()
  local prim = Sel.primary(ctx)
  if st.selType == SelType.JOIN and Sel.hasSelection(prim) then
    joinKill(ctx)
    return
  end
  if Sel.hasSelection(prim) then
    ctx.clipboard:write(joinedKillText(ctx, text, regionsInOrder(ctx.port:getSelections())))
    editCarets(ctx, function(sel, lo, hi)
      if lo == hi then
        return { edit = nil, sel = sel }
      end
      local r = killRange(ctx, sel, text)
      return { edit = { start = r.lo, stop = r.hi, text = '' }, sel = { anchor = r.lo, active = r.lo } }
    end)
    st.selType = SelType.NONE
    return
  end
  if #text == 0 then
    return
  end
  local caret = prim.active
  local ln = text_.lineOfOffset(text, caret)
  local eol = text_.lineEnd(text, ln)
  local stop = caret == eol and text_.lineStart(text, ln + 1) or eol
  if stop > caret then
    ctx.clipboard:write(text_.slice(text, caret, stop))
    local edits = { { start = caret, stop = stop, text = '' } }
    Grab.adjustForEdits(st, edits)
    ctx.port:edit(edits)
    ctx.port:setSelections({ { anchor = caret, active = caret } })
  end
end

local function save(ctx)
  local text = ctx.port:getText()
  local sels = ctx.port:getSelections()
  local withSel = regionsInOrder(sels)
  if #withSel == 0 then
    return
  end
  ctx.clipboard:write(joinedKillText(ctx, text, withSel))
  local moved = {}
  for i, s in ipairs(sels) do
    if s.anchor == s.active then
      moved[i] = s
    else
      local r = killRange(ctx, s, text)
      local caret = s.active >= s.anchor and r.hi or r.lo
      moved[i] = { anchor = caret, active = caret }
    end
  end
  ctx.port:setSelections(moved)
  ctx.st.selType = SelType.NONE
  ctx.st.selExpand = false
end

local function yank(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  local clip = ctx.clipboard:read()
  if clip == nil or clip == '' then
    return
  end
  editCarets(ctx, function(sel)
    return {
      edit = { start = sel.active, stop = sel.active, text = clip },
      sel = { anchor = sel.active + #clip, active = sel.active + #clip },
    }
  end)
end

local function replace(ctx)
  if not allowModify(ctx) then
    return
  end
  if not Sel.hasSelection(Sel.primary(ctx)) then
    return
  end
  local raw = ctx.clipboard:read()
  if raw == nil then
    return
  end
  local clip = raw:gsub('\n+$', '')
  editCarets(ctx, function(sel, lo, hi)
    if lo == hi then
      return { edit = nil, sel = sel }
    end
    return {
      edit = { start = lo, stop = hi, text = clip },
      sel = { anchor = lo + #clip, active = lo + #clip },
    }
  end)
  ctx.st.selType = SelType.NONE
end

local function capitalizedWords(slice)
  local pred = text_.charPred(false)
  local out = {}
  local inWord = false
  for i = 1, #slice do
    local c = slice:sub(i, i)
    if pred(c) then
      table.insert(out, inWord and c:lower() or c:upper())
      inWord = true
    else
      table.insert(out, c)
      inWord = false
    end
  end
  return table.concat(out)
end

local function casified(slice, op)
  if op == 'upcase' then
    return slice:upper()
  end
  if op == 'downcase' then
    return slice:lower()
  end
  return capitalizedWords(slice)
end

local function caseWord(ctx, op)
  if M.blockedReadOnly(ctx) then
    return
  end
  local n = ctx.st:takeCount(1)
  if n == 0 then
    return
  end
  local hadSelection = Sel.hasSelection(Sel.primary(ctx))
  local text = ctx.port:getText()
  local pred = text_.charPred(false)
  editCarets(ctx, function(sel)
    local from = sel.active
    local target
    if n > 0 then
      target = text_.Words.nextEnd(text, from, n, pred)
    else
      target = text_.Words.prevStart(text, from, -n, pred)
    end
    local s = math.min(from, target)
    local e = math.max(from, target)
    if s == e then
      return { edit = nil, sel = sel }
    end
    local caret = n > 0 and e or from
    return {
      edit = { start = s, stop = e, text = casified(text_.slice(text, s, e), op) },
      sel = { anchor = caret, active = caret },
    }
  end)
  if hadSelection then
    Sel.collapse(ctx)
  end
end

local function killWord(ctx)
  if M.blockedReadOnly(ctx) then
    return
  end
  local n = ctx.st:takeCount(1)
  if n == 0 then
    return
  end
  local text = ctx.port:getText()
  local pred = text_.charPred(false)
  local function rangeAt(from)
    local target
    if n > 0 then
      target = text_.Words.nextEnd(text, from, n, pred)
    else
      target = text_.Words.prevStart(text, from, -n, pred)
    end
    return { lo = math.min(from, target), hi = math.max(from, target) }
  end
  local killed = {}
  for _, sel in ipairs(ctx.port:getSelections()) do
    local r = rangeAt(sel.active)
    if r.lo ~= r.hi then
      table.insert(killed, r)
    end
  end
  table.sort(killed, function(a, b)
    return a.lo < b.lo
  end)
  if #killed == 0 then
    return
  end
  local parts = {}
  for _, r in ipairs(killed) do
    table.insert(parts, text_.slice(text, r.lo, r.hi))
  end
  ctx.clipboard:write(table.concat(parts, '\n'))
  editCarets(ctx, function(sel)
    local r = rangeAt(sel.active)
    if r.lo == r.hi then
      return { edit = nil, sel = { anchor = sel.active, active = sel.active } }
    end
    return { edit = { start = r.lo, stop = r.hi, text = '' }, sel = { anchor = r.lo, active = r.lo } }
  end)
  ctx.st.selType = SelType.NONE
  ctx.st.selExpand = false
end

local function undo(ctx)
  if Sel.hasSelection(Sel.primary(ctx)) then
    Sel.cancel(ctx)
  end
  ctx.port:undo()
end

local function undoInSelection(ctx)
  if Sel.hasSelection(Sel.primary(ctx)) then
    ctx.port:undo()
  end
end

M.commands = {
  ['meow-insert'] = insert,
  ['meow-append'] = append,
  ['meow-open-above'] = openAbove,
  ['meow-open-below'] = openBelow,
  ['meow-change'] = change,
  ['meow-delete'] = del,
  ['meow-backward-delete'] = backwardDelete,
  ['meow-kill'] = kill,
  ['meow-save'] = save,
  ['meow-yank'] = yank,
  ['meow-replace'] = replace,
  ['meow-undo'] = undo,
  ['meow-undo-in-selection'] = undoInSelection,
  ['upcase-word'] = function(ctx)
    caseWord(ctx, 'upcase')
  end,
  ['downcase-word'] = function(ctx)
    caseWord(ctx, 'downcase')
  end,
  ['capitalize-word'] = function(ctx)
    caseWord(ctx, 'capitalize')
  end,
  ['kill-word'] = killWord,
  ['open-line'] = openLine,
  ['delete-horizontal-space'] = function(ctx)
    horizontalSpace(ctx, '')
  end,
  ['just-one-space'] = function(ctx)
    horizontalSpace(ctx, ' ')
  end,
}

return M
