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

local M = {}

local PLAIN_KEYS = {
  SPC = ' ',
  SPACE = ' ',
  TAB = '\t',
  COMMA = ',',
  PERIOD = '.',
  SLASH = '/',
  SEMICOLON = ';',
  QUOTE = "'",
  OPEN_BRACKET = '[',
  CLOSE_BRACKET = ']',
  BACK_SLASH = '\\',
  MINUS = '-',
  EQUALS = '=',
  BACK_QUOTE = '`',
  BSLASH = '\\',
  BAR = '|',
  LT = '<',
}

local SHIFTED_KEYS = {
  COMMA = '<',
  PERIOD = '>',
  SLASH = '?',
  SEMICOLON = ':',
  QUOTE = '"',
  OPEN_BRACKET = '{',
  CLOSE_BRACKET = '}',
  BACK_SLASH = '|',
  MINUS = '_',
  EQUALS = '+',
  BACK_QUOTE = '~',
  ['1'] = '!',
  ['2'] = '@',
  ['3'] = '#',
  ['4'] = '$',
  ['5'] = '%',
  ['6'] = '^',
  ['7'] = '&',
  ['8'] = '*',
  ['9'] = '(',
  ['0'] = ')',
}

local HOST_MODIFIERS = {
  control = 'ctrl',
  ctrl = 'ctrl',
  alt = 'alt',
  meta = 'alt',
  shift = 'shift',
}

local PREFIX_MODIFIERS = {
  C = 'ctrl',
  M = 'alt',
  A = 'alt',
  S = 'shift',
}

local function isLowerLetter(char)
  return char:match('^%l$') ~= nil
end

local function isUpperLetter(char)
  return char:match('^%u$') ~= nil
end

function M.named(token, shift)
  local name = token:upper()
  if shift and SHIFTED_KEYS[name] ~= nil then
    return SHIFTED_KEYS[name]
  end
  if PLAIN_KEYS[name] ~= nil then
    return PLAIN_KEYS[name]
  end
  return #token == 1 and token or nil
end

local function parseHostSpelling(text)
  local tokens = {}
  for token in text:gmatch('%S+') do
    table.insert(tokens, token)
  end
  local mods = { ctrl = false, alt = false, shift = false }
  for i = 1, #tokens - 1 do
    local mod = HOST_MODIFIERS[tokens[i]:lower()]
    if mod == nil then
      return nil
    end
    mods[mod] = true
  end
  local named = M.named(tokens[#tokens] or '', mods.shift)
  if named == nil or not (mods.ctrl or mods.alt) then
    return nil
  end
  return {
    ctrl = mods.ctrl,
    alt = mods.alt,
    shift = mods.shift and isLowerLetter(named:lower()),
    key = named:lower(),
  }
end

local function parsePrefixSpelling(text)
  local rest = text
  local mods = { ctrl = false, alt = false, shift = false }
  while #rest > 2 and rest:sub(2, 2) == '-' do
    local mod = PREFIX_MODIFIERS[rest:sub(1, 1):upper()]
    if mod == nil then
      return nil
    end
    mods[mod] = true
    rest = rest:sub(3)
  end
  local named = M.named(rest, mods.shift)
  if named == nil or not (mods.ctrl or mods.alt) then
    return nil
  end
  if isUpperLetter(named) then
    return { ctrl = mods.ctrl, alt = mods.alt, shift = true, key = named:lower() }
  end
  return { ctrl = mods.ctrl, alt = mods.alt, shift = mods.shift, key = named }
end

function M.parse(text)
  local rest = text:match('^%s*(.-)%s*$')
  if rest == '' then
    return nil
  end
  if #rest > 2 and rest:sub(1, 1) == '<' and rest:sub(-1) == '>' then
    rest = rest:sub(2, -2)
  end
  if rest:find('%s') ~= nil then
    return parseHostSpelling(rest)
  end
  return parsePrefixSpelling(rest)
end

function M.modifierPrefix(chord)
  return (chord.ctrl and 'C-' or '') .. (chord.alt and 'M-' or '') .. (chord.shift and 'S-' or '')
end

function M.spelling(chord)
  return M.modifierPrefix(chord) .. chord.key
end

function M.keyOf(text)
  local chord = M.parse(text)
  if chord == nil then
    return nil
  end
  return M.spelling(chord)
end

return M
