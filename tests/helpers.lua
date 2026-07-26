-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local core = require('neomeow.core')
local Engine = core.engine
local registry = core.registry
local Rc = core.rc
local state = core.state
local text_ = core.text
local MeowMode = state.MeowMode
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
  for i, s in ipairs(self.sels) do
    out[i] = { anchor = s.anchor, active = s.active }
  end
  return out
end

function FakeEditor:setSelections(sels)
  local out = {}
  for i, s in ipairs(sels) do
    out[i] = { anchor = s.anchor, active = s.active }
  end
  self.sels = out
end

function FakeEditor:edit(edits)
  local sorted = {}
  for i, e in ipairs(edits) do
    sorted[i] = e
  end
  table.sort(sorted, function(a, b)
    return a.start > b.start
  end)
  for _, e in ipairs(sorted) do
    self.text = self.text:sub(1, e.start) .. e.text .. self.text:sub(e.stop + 1)
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

function FakeUi:modeChanged(st)
  table.insert(self.modes, st.mode)
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
  return { port = self.editor, clipboard = self.clip, ui = self.ui, rx = self.rx, st = self.st }
end

function Spec:given(_description, textWithCaret)
  local at = textWithCaret:find('<caret>', 1, true)
  self.editor.text = (textWithCaret:gsub('<caret>', '', 1))
  local off = at == nil and 0 or (at - 1)
  self.editor.sels = { { anchor = off, active = off } }
  self.st = state.newState()
end

function Spec.givenRc(_, text)
  Rc.setForTest(Rc.parse(vim.split(text, '\n', { plain = true })))
end

function Spec:givenClipboard(text)
  self.clip.content = text
end

function Spec:givenMinibufferAnswers(...)
  for _, a in ipairs({ ... }) do
    table.insert(self.ui.answers, a)
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
  local session = self.st.avy
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
  local s = self.editor.sels[1]
  if s.anchor == s.active then
    return nil
  end
  return self.editor.text:sub(math.min(s.anchor, s.active) + 1, math.max(s.anchor, s.active))
end

function Spec:caretLine()
  return text_.lineOfOffset(self.editor.text, self.editor.sels[1].active)
end

function Spec:thenSelection(expected)
  eq(self:selectedText(), expected, 'selected text')
end

function Spec:thenNoSelection()
  local s = self.editor.sels[1]
  eq(s.anchor, s.active, 'expected no selection')
end

function Spec:thenCaretAt(offset)
  eq(self.editor.sels[1].active, offset, 'caret offset')
end

function Spec:thenCaretAtSelectionStart()
  local s = self.editor.sels[1]
  neq(s.anchor, s.active, 'expected a selection')
  eq(s.active, math.min(s.anchor, s.active), 'caret at selection start (reversed)')
end

function Spec:thenCaretAtSelectionEnd()
  local s = self.editor.sels[1]
  neq(s.anchor, s.active, 'expected a selection')
  eq(s.active, math.max(s.anchor, s.active), 'caret at selection end (forward)')
end

function Spec:thenText(expected)
  eq(self.editor.text, expected, 'buffer text')
end

function Spec:thenMode(expected)
  eq(self.st.mode, expected, 'meow mode')
end

function Spec:thenSelType(expected)
  eq(self.st.selType, expected, 'selection type')
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
  local s = setmetatable({
    editor = newFakeEditor(),
    clip = setmetatable({ content = nil }, FakeClipboard),
    ui = newFakeUi(),
    rx = makeRx(),
    st = state.newState(),
  }, Spec)
  return s
end

M.MeowMode = MeowMode
M.SelType = state.SelType
M.Pending = state.Pending

return M
