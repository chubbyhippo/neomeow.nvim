-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local core = require('neomeow.core')
local Engine = core.engine
local registry = core.registry
local Rc = core.rc
local State = core.state
local text_ = core.text
local MeowMode = State.MeowMode
local suite = require('tests.suite')

local M = {}

M.describe = suite.describe
M.it = suite.it

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'assertion failed') .. ': expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual), 2)
  end
end
M.eq = eq

local function neq(actual, unexpected, msg)
  if actual == unexpected then
    error((msg or 'assertion failed') .. ': did not expect ' .. vim.inspect(unexpected), 2)
  end
end
M.neq = neq

local function ok(cond, msg)
  if not cond then
    error(msg or 'expected truthy', 2)
  end
end
M.ok = ok

local function eqList(actual, expected, msg)
  local same = type(actual) == 'table' and #actual == #expected
  if same then
    for i = 1, #expected do
      if actual[i] ~= expected[i] then
        same = false
        break
      end
    end
  end
  if not same then
    error((msg or 'list mismatch') .. ': expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual), 2)
  end
end
M.eqList = eqList

local function eqTable(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error((msg or 'table mismatch') .. ': expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual), 2)
  end
end
M.eqTable = eqTable

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

local FakeEditor = {}
FakeEditor.__index = FakeEditor

local function newFakeEditor()
  return setmetatable({
    text = '',
    sels = { { anchor = 0, active = 0 } },
    writable = true,
    visible = nil,
    undoCount = 0,
  }, FakeEditor)
end

function FakeEditor:getText()
  return self.text
end

function FakeEditor:getSelections()
  local out = {}
  for i, sel in ipairs(self.sels) do
    out[i] = { anchor = sel.anchor, active = sel.active }
  end
  return out
end

function FakeEditor:setSelections(sels)
  local out = {}
  for i, sel in ipairs(sels) do
    out[i] = { anchor = sel.anchor, active = sel.active }
  end
  self.sels = out
end

function FakeEditor:edit(edits)
  local sorted = {}
  for i, edit in ipairs(edits) do
    sorted[i] = edit
  end
  table.sort(sorted, function(a, b)
    return a.start > b.start
  end)
  for _, edit in ipairs(sorted) do
    self.text = self.text:sub(1, edit.start) .. edit.text .. self.text:sub(edit.stop + 1)
  end
end

function FakeEditor:isWritable()
  return self.writable
end

function FakeEditor:visibleLineRange()
  return self.visible
end

function FakeEditor:undo()
  self.undoCount = self.undoCount + 1
end

function FakeEditor.closeEditor() end

function FakeEditor.symbolRangeAt()
  return nil
end

local FakeClipboard = {}
FakeClipboard.__index = FakeClipboard

function FakeClipboard:read()
  return self.content
end

function FakeClipboard:write(text)
  self.content = text
end

local FakeUi = {}
FakeUi.__index = FakeUi

local function newFakeUi()
  return setmetatable({
    hints = {},
    infos = {},
    answers = {},
    ran = {},
    modes = {},
    expandHints = {},
    avyMatches = {},
    avyLabels = {},
    grab = nil,
    revealed = {},
    timerSeq = 0,
    timers = {},
  }, FakeUi)
end

function FakeUi:hint(text)
  table.insert(self.hints, text)
end

function FakeUi:info(title, body)
  table.insert(self.infos, { title, body })
end

function FakeUi:input()
  return table.remove(self.answers, 1)
end

function FakeUi:runCommand(id)
  table.insert(self.ran, id)
end

function FakeUi.scheduleWhichKey() end
function FakeUi.hideWhichKey() end

function FakeUi:showExpandHints(positions)
  self.expandHints = positions
end

function FakeUi:clearExpandHints()
  self.expandHints = {}
end

function FakeUi:showAvyMatches(ranges)
  self.avyMatches = ranges
end

function FakeUi:showAvyLabels(labels)
  self.avyLabels = labels
end

function FakeUi:clearAvy()
  self.avyMatches = {}
  self.avyLabels = {}
end

function FakeUi:setGrabHighlight(range)
  self.grab = range
end

function FakeUi:revealCaret(at)
  table.insert(self.revealed, at)
end

function FakeUi:modeChanged(state)
  table.insert(self.modes, state.mode)
end

function FakeUi.refresh() end

function FakeUi:startTimer(_ms, cb)
  self.timerSeq = self.timerSeq + 1
  self.timers[self.timerSeq] = cb
  return self.timerSeq
end

function FakeUi:cancelTimer(id)
  self.timers[id] = nil
end

local Spec = {}
Spec.__index = Spec

function Spec:ctx()
  return { port = self.editor, clipboard = self.clip, ui = self.ui, rx = self.rx, state = self.state }
end

function Spec:given(_description, textWithCaret)
  local at = textWithCaret:find('<caret>', 1, true)
  self.editor.text = (textWithCaret:gsub('<caret>', '', 1))
  local offset = at == nil and 0 or (at - 1)
  self.editor.sels = { { anchor = offset, active = offset } }
  self.state = State.newState()
end

function Spec.givenRc(_, text)
  Rc.setForTest(Rc.parse(vim.split(text, '\n', { plain = true })))
end

function Spec:givenClipboard(text)
  self.clip.content = text
end

function Spec:givenMinibufferAnswers(...)
  for _, answer in ipairs({ ... }) do
    table.insert(self.ui.answers, answer)
  end
end

function Spec:givenCaretAt(offset)
  self.editor.sels = { { anchor = offset, active = offset } }
end

function Spec:givenReadOnly()
  self.editor.writable = false
end

function Spec:whenKeys(keys)
  for i = 1, #keys do
    Engine.handleChar(self:ctx(), keys:sub(i, i))
  end
end

function Spec:whenCommand(name)
  local cmd = registry.COMMANDS[name]
  if cmd == nil then
    error('unknown command: ' .. name)
  end
  cmd(self:ctx())
end

function Spec:fireAvyTimer()
  local session = self.state.avy
  if session ~= nil and session.timer ~= nil then
    local cb = self.ui.timers[session.timer]
    if cb ~= nil then
      cb()
    end
  end
end

function Spec:pressEsc()
  return Engine.escapeKey(self:ctx())
end

function Spec:selectedText()
  local sel = self.editor.sels[1]
  if sel.anchor == sel.active then
    return nil
  end
  return self.editor.text:sub(math.min(sel.anchor, sel.active) + 1, math.max(sel.anchor, sel.active))
end

function Spec:caretLine()
  return text_.lineOfOffset(self.editor.text, self.editor.sels[1].active)
end

function Spec:thenSelection(expected)
  eq(self:selectedText(), expected, 'selected text')
end

function Spec:thenNoSelection()
  local sel = self.editor.sels[1]
  eq(sel.anchor, sel.active, 'expected no selection')
end

function Spec:thenCaretAt(offset)
  eq(self.editor.sels[1].active, offset, 'caret offset')
end

function Spec:thenCaretAtSelectionStart()
  local sel = self.editor.sels[1]
  neq(sel.anchor, sel.active, 'expected a selection')
  eq(sel.active, math.min(sel.anchor, sel.active), 'caret at selection start (reversed)')
end

function Spec:thenCaretAtSelectionEnd()
  local sel = self.editor.sels[1]
  neq(sel.anchor, sel.active, 'expected a selection')
  eq(sel.active, math.max(sel.anchor, sel.active), 'caret at selection end (forward)')
end

function Spec:thenText(expected)
  eq(self.editor.text, expected, 'buffer text')
end

function Spec:thenMode(expected)
  eq(self.state.mode, expected, 'meow mode')
end

function Spec:thenSelType(expected)
  eq(self.state.selType, expected, 'selection type')
end

function Spec:thenClipboard(expected)
  eq(self.clip.content, expected, 'clipboard')
end

function Spec:thenCaretCount(expected)
  eq(#self.editor.sels, expected, 'caret count')
end

local defaultsLoaded = false

function M.freshSpec()
  if not defaultsLoaded then
    Rc.initDefaults(vim.split(require('neomeow.default_rc'), '\n', { plain = true }))
    defaultsLoaded = true
  end
  Rc.setForTest(Rc.newConfig())
  Engine.clearRepeat()
  return setmetatable({
    editor = newFakeEditor(),
    clip = setmetatable({ content = nil }, FakeClipboard),
    ui = newFakeUi(),
    rx = makeRx(),
    state = State.newState(),
  }, Spec)
end

M.MeowMode = MeowMode
M.SelType = State.SelType
M.Pending = State.Pending

return M
