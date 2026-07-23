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

registry.register(require('neomeow.core.motions').commands)
registry.register(require('neomeow.core.selections').commands)
registry.register(require('neomeow.core.search').commands)
registry.register(require('neomeow.core.structures').commands)
registry.register(require('neomeow.core.grab').commands)
registry.register(require('neomeow.core.edits').commands)
registry.register(require('neomeow.core.avy').commands)
registry.register(require('neomeow.core.acewindow').commands)
require('neomeow.core.engine')

return {
  engine = require('neomeow.core.engine'),
  registry = registry,
  rc = require('neomeow.core.rc'),
  state = require('neomeow.core.state'),
  port = require('neomeow.core.port'),
  attachpolicy = require('neomeow.core.attachpolicy'),
  keypad = require('neomeow.core.keypad'),
  whichkey = require('neomeow.core.whichkey'),
  hints = require('neomeow.core.hints'),
  avy = require('neomeow.core.avy'),
  treemeow = require('neomeow.core.treemeow'),
  toolwindowescape = require('neomeow.core.toolwindowescape'),
  rcstate = require('neomeow.core.rcstate'),
  text = require('neomeow.core.text'),
}
