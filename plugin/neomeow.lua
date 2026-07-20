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

if vim.g.loaded_neomeow then
  return
end
vim.g.loaded_neomeow = true

vim.api.nvim_create_user_command('Neomeow', function()
  require('neomeow').setup()
  require('neomeow').attach(vim.api.nvim_get_current_buf())
end, { desc = 'Enable neomeow with defaults and attach the current buffer' })
