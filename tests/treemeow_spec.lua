-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local h = require('tests.helpers')
local Rc = require('neomeow.core.rc')
local TreeMeow = require('neomeow.core.treemeow')

describe('TreeMeowSpec', function()
  local TreeNode = {}
  TreeNode.__index = TreeNode

  local function newNode(name, parent)
    return setmetatable({ name = name, parent = parent, children = {}, expanded = false }, TreeNode)
  end

  function TreeNode:add(name)
    local child = newNode(name, self)
    table.insert(self.children, child)
    return child
  end

  local FakeTree = {}
  FakeTree.__index = FakeTree

  local function visibleRows(tree)
    local rows = {}
    local function walk(n)
      table.insert(rows, n)
      if n.expanded then
        for _, c in ipairs(n.children) do
          walk(c)
        end
      end
    end
    walk(tree.root)
    return rows
  end

  local function indexOf(rows, node)
    for i, r in ipairs(rows) do
      if r == node then
        return i
      end
    end
    return nil
  end

  function FakeTree:run(id)
    local rows = visibleRows(self)
    local at = indexOf(rows, self.focus)
    if id == 'neomeow.tree.focusDown' then
      self.focus = rows[math.min(at + 1, #rows)]
    elseif id == 'neomeow.tree.focusUp' then
      self.focus = rows[math.max(at - 1, 1)]
    elseif id == 'neomeow.tree.collapse' then
      if self.focus.expanded then
        self.focus.expanded = false
      elseif self.focus.parent ~= nil then
        self.focus = self.focus.parent
      end
    elseif id == 'neomeow.tree.expand' then
      if #self.focus.children > 0 and not self.focus.expanded then
        self.focus.expanded = true
      elseif #self.focus.children > 0 then
        self.focus = self.focus.children[1]
      end
    else
      table.insert(self.ran, id)
    end
  end

  local function findNode(n, name)
    if n.name == name then
      return n
    end
    for _, c in ipairs(n.children) do
      local r = findNode(c, name)
      if r ~= nil then
        return r
      end
    end
    return nil
  end

  function FakeTree:select(name)
    self.focus = findNode(self.root, name)
  end

  function FakeTree:selectedText()
    return self.focus.name
  end

  function FakeTree:isExpanded(name)
    local prior = self.focus
    self:select(name)
    local expanded = self.focus.expanded
    self.focus = prior
    return expanded
  end

  function FakeTree:runner()
    return function(id)
      self:run(id)
    end
  end

  local function givenTree()
    local tree = setmetatable({ root = newNode('root', nil), ran = {} }, FakeTree)
    tree.focus = tree.root
    local a = tree.root:add('a')
    a:add('a1')
    a:add('a2')
    tree.root:add('b')
    tree.root.expanded = true
    return tree
  end

  it('given the bundled rc then it binds the tree keys', function()
    h.freshSpec()
    local d = Rc.defaults().motion
    h.eq(d['j'].command, 'meow-next')
    h.eq(d['k'].command, 'meow-prev')
    h.eq(d['h'].command, 'meow-left')
    h.eq(d['l'].command, 'meow-right')
    h.eq(d['q'].action, 'close')
  end)

  it('given a tree when j and k then the selection moves like the arrow keys', function()
    h.freshSpec()
    local tree = givenTree()
    TreeMeow.dispatch(tree:runner(), 'j')
    h.eq(tree:selectedText(), 'a')
    TreeMeow.dispatch(tree:runner(), 'j')
    h.eq(tree:selectedText(), 'b')
    TreeMeow.dispatch(tree:runner(), 'k')
    h.eq(tree:selectedText(), 'a')
  end)

  it('given a collapsed node when l then it expands, and l again enters it', function()
    h.freshSpec()
    local tree = givenTree()
    tree:select('a')
    TreeMeow.dispatch(tree:runner(), 'l')
    h.ok(tree:isExpanded('a'), 'l on a collapsed node expands it')
    h.eq(tree:selectedText(), 'a')
    TreeMeow.dispatch(tree:runner(), 'l')
    h.eq(tree:selectedText(), 'a1')
  end)

  it('given an expanded node when h then it collapses, then goes to the parent', function()
    h.freshSpec()
    local tree = givenTree()
    tree:select('a')
    tree.focus.expanded = true
    tree:select('a1')
    TreeMeow.dispatch(tree:runner(), 'h')
    h.eq(tree:selectedText(), 'a')
    TreeMeow.dispatch(tree:runner(), 'h')
    h.eq(tree:isExpanded('a'), false, 'h on an expanded node collapses it')
    h.eq(tree:selectedText(), 'a')
    TreeMeow.dispatch(tree:runner(), 'h')
    h.eq(tree:selectedText(), 'root')
  end)

  it('given an editor-only command in the mmap then it is inert on trees', function()
    local s = h.freshSpec()
    s:givenRc('mmap w meow-next-word')
    local tree = givenTree()
    TreeMeow.dispatch(tree:runner(), 'w')
    h.eq(tree:selectedText(), 'root', 'a word motion has no tree meaning')
    h.eqList(tree.ran, {})
  end)

  it('given a user mmap override then it shadows the bundled defaults', function()
    local s = h.freshSpec()
    s:givenRc('mmap j ignore')
    local tree = givenTree()
    TreeMeow.dispatch(tree:runner(), 'j')
    h.eq(tree:selectedText(), 'root')
  end)

  it('given a keys mapping then the replay resolves every key through the motion map', function()
    local s = h.freshSpec()
    s:givenRc('mmap g jj')
    local tree = givenTree()
    TreeMeow.dispatch(tree:runner(), 'g')
    h.eq(tree:selectedText(), 'b')
  end)

  it('given a noremap replay then it skips user maps like the engine', function()
    local s = h.freshSpec()
    s:givenRc('mnoremap g jj\nmmap j ignore')
    local tree = givenTree()
    TreeMeow.dispatch(tree:runner(), 'j')
    h.eq(tree:selectedText(), 'root', 'a user-shadowed j is inert')
    TreeMeow.dispatch(tree:runner(), 'g')
    h.eq(tree:selectedText(), 'b', 'the replay resolves j via the defaults')
  end)

  it('given an <action> mmap then it dispatches with the tree as context', function()
    local s = h.freshSpec()
    s:givenRc('mmap z <action>(neomeow.test.probe)')
    local tree = givenTree()
    TreeMeow.dispatch(tree:runner(), 'z')
    h.eqList(tree.ran, { 'neomeow.test.probe' })
  end)

  it('given defaults and user maps then boundChars merges them', function()
    local s = h.freshSpec()
    s:givenRc('mmap w meow-next-word')
    local bound = TreeMeow.boundChars()
    for c in ('jkhlqw'):gmatch('.') do
      h.ok(bound[c], "'" .. c .. "' must be bound")
    end
    h.eq(bound['z'] ~= nil, false, 'unmapped letters stay native (type-to-find)')
  end)

  it('given mmap q ignore then the key returns to the tree', function()
    local s = h.freshSpec()
    s:givenRc('mmap q ignore')
    h.eq(TreeMeow.boundChars()['q'] ~= nil, false, 'an ignored key leaves the shortcut set')
    h.ok(TreeMeow.boundChars()['j'], 'the other defaults stay')
  end)
end)
