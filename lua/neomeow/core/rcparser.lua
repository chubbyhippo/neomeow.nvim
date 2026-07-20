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

local registry = require('neomeow.core.registry')

local M = {}

function M.newConfig()
  return {
    normal = {},
    motion = {},
    keypad = {},
    keypadOrder = {},
    keypadDesc = {},
    keypadDescOrder = {},
    repeatGroups = {},
    repeatOrder = {},
    whichKey = nil,
    whichKeyDelayMs = nil,
    errors = {},
  }
end

local function orderedSet(map, order, key, value)
  if map[key] == nil then
    table.insert(order, key)
  end
  map[key] = value
end

local function commentStart(line)
  local depth = 0
  for i = 1, #line do
    local ch = line:sub(i, i)
    if ch == '(' then
      depth = depth + 1
    elseif ch == ')' then
      if depth > 0 then
        depth = depth - 1
      end
    elseif ch == '"' and depth == 0 and i > 1 and line:sub(i - 1, i - 1):match('%s') ~= nil then
      return i - 1
    end
  end
  return nil
end

local function parseKeys(s, err)
  local out = {}
  local i = 1
  while i <= #s do
    local ch = s:sub(i, i)
    if ch == '<' then
      local close = s:find('>', i, true)
      if close == nil then
        table.insert(out, ch)
        i = i + 1
      else
        local token = s:sub(i + 1, close - 1):lower()
        if token == 'space' then
          table.insert(out, ' ')
        elseif token == 'lt' then
          table.insert(out, '<')
        else
          err('unsupported key token ' .. s:sub(i, close) .. ' (only printable keys reach the meow engine)')
          return nil
        end
        i = close + 1
      end
    else
      table.insert(out, ch)
      i = i + 1
    end
  end
  return table.concat(out)
end

local function parseTarget(rhs, recursive, errContext, err)
  local action = rhs:match('^[<][Aa][Cc][Tt][Ii][Oo][Nn][>]%((.+)%)$')
  if action ~= nil then
    return { action = action, recursive = recursive }
  end
  if registry.COMMANDS[rhs] ~= nil then
    return { command = rhs, recursive = recursive }
  end
  if rhs:sub(1, 5) == 'meow-' then
    err("unknown meow command '" .. rhs .. "'")
    return nil
  end
  local keys = parseKeys(rhs:gsub('%s+', ''), err)
  if keys == nil then
    return nil
  end
  if keys == '' then
    err("empty target in '" .. errContext .. "'")
    return nil
  end
  return { keys = keys, recursive = recursive }
end

local function parseSet(c, rest)
  if rest == 'which-key' then
    c.whichKey = true
  elseif rest == 'nowhich-key' then
    c.whichKey = false
  elseif rest:sub(1, 10) == 'timeoutlen' then
    local eqPos = rest:find('=', 1, true)
    local n
    if eqPos ~= nil then
      n = tonumber(rest:sub(eqPos + 1):match('^%s*(%-?%d+)%s*$'))
    else
      n = tonumber((rest:match('^%S+%s+(%S+)') or ''):match('^%-?%d+$'))
    end
    if n ~= nil and n >= 0 then
      c.whichKeyDelayMs = n
    end
  end
end

local function parseDescBody(c, body, err)
  if body:sub(1, 8) ~= '<leader>' then
    err('descriptions must start with <leader>: ' .. body)
    return
  end
  local after = body:sub(9)
  local seqToken = after:match('^%S*')
  local desc = after:sub(#seqToken + 1):match('^%s*(.-)%s*$')
  local seq = parseKeys(seqToken, err)
  if seq == nil then
    return
  end
  if seq == '' then
    err('empty key sequence in description: ' .. body)
    return
  end
  orderedSet(c.keypadDesc, c.keypadDescOrder, seq, desc)
end

local function parseMap(c, cmd, rest, err)
  local lhs, rhs = rest:match('^(%S+)%s+(.*)$')
  if lhs == nil then
    err(cmd .. ' needs a key and a target')
    return
  end
  rhs = rhs:match('^%s*(.-)%s*$')
  local recursive = cmd == 'map' or cmd == 'nmap' or cmd == 'mmap'
  local motion = cmd == 'mmap' or cmd == 'mnoremap'

  local binding = parseTarget(rhs, recursive, cmd .. ' ' .. rest, err)
  if binding == nil then
    return
  end

  if lhs:sub(1, 8) == '<leader>' then
    if motion then
      err(cmd .. ' cannot define keypad entries; use map <leader>...')
      return
    end
    local seq = parseKeys(lhs:sub(9), err)
    if seq == nil then
      return
    end
    if seq == '' then
      err('<leader> alone cannot be mapped')
    elseif ('0123456789?/'):find(seq:sub(1, 1), 1, true) ~= nil then
      err('keypad ' .. seq:sub(1, 1) .. ' is reserved (digit argument / cheatsheet / describe)')
    else
      orderedSet(c.keypad, c.keypadOrder, seq, binding)
    end
    return
  end

  local keys = parseKeys(lhs, err)
  if keys == nil then
    return
  end
  if #keys ~= 1 then
    err((motion and 'motion' or 'normal') .. '-mode key must be a single printable key: ' .. lhs)
  elseif keys == ' ' then
    err('SPC is the keypad key and cannot be remapped')
  else
    local target = motion and c.motion or c.normal
    target[keys] = binding
  end
end

local function parseRepeat(c, rest, err)
  local group, keyToken, rhs = rest:match('^(%S+)%s+(%S+)%s+(.*)$')
  if group == nil then
    err('repeat needs a group, a member key and a target')
    return
  end
  local key = parseKeys(keyToken, err)
  if key == nil then
    return
  end
  if #key ~= 1 then
    err('repeat member key must be a single printable key: ' .. keyToken)
  elseif key == ' ' then
    err('SPC is the keypad key and cannot be a repeat member')
  else
    local binding = parseTarget(rhs:match('^%s*(.-)%s*$'), true, 'repeat ' .. rest, err)
    if binding == nil then
      return
    end
    local members = c.repeatGroups[group]
    if members == nil then
      members = { map = {}, order = {} }
      table.insert(c.repeatOrder, group)
      c.repeatGroups[group] = members
    end
    orderedSet(members.map, members.order, key, binding)
  end
end

function M.parse(lines)
  local c = M.newConfig()
  for i, raw in ipairs(lines) do
    local line = raw:match('^%s*(.-)%s*$')
    local function err(msg)
      table.insert(c.errors, 'line ' .. i .. ': ' .. msg)
    end

    local skip = line == '' or line:sub(1, 1) == '"' or line:sub(1, 1) == '#'
    if not skip then
      local wk = line:match('^let%s+g:WhichKeyDesc[%w_]*%s*=%s*"(.+)"$')
      if wk ~= nil then
        parseDescBody(c, wk, err)
      else
        local cut = commentStart(line)
        if cut ~= nil then
          line = line:sub(1, cut - 1):match('^(.-)%s*$')
        end
        if line ~= '' then
          local cmd, rest = line:match('^(%S+)%s*(.*)$')
          rest = rest:match('^%s*(.-)%s*$')
          if cmd == 'let' then
          elseif cmd == 'set' then
            parseSet(c, rest)
          elseif cmd == 'desc' then
            parseDescBody(c, rest, err)
          elseif
            cmd == 'map'
            or cmd == 'noremap'
            or cmd == 'nmap'
            or cmd == 'nnoremap'
            or cmd == 'mmap'
            or cmd == 'mnoremap'
          then
            parseMap(c, cmd, rest, err)
          elseif cmd == 'repeat' then
            parseRepeat(c, rest, err)
          else
            err("unknown command '" .. cmd .. "'")
          end
        end
      end
    end
  end
  return c
end

return M
