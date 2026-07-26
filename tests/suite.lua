-- Copyright (C) 2026 Chubby Hippo
-- SPDX-License-Identifier: GPL-3.0-or-later
-- (see LICENSE for the full GPL-3.0-or-later text)

local M = {}

local suites = {}
local current = nil

function M.describe(name, fn)
  current = { name = name, passed = 0, failures = {} }
  table.insert(suites, current)
  fn()
  current = nil
end

function M.it(name, fn)
  local ok, err = xpcall(fn, function(e)
    return debug.traceback(tostring(e), 2)
  end)
  if ok then
    current.passed = current.passed + 1
  else
    table.insert(current.failures, { name = name, err = err })
  end
end

function M.results()
  return suites
end

return M
