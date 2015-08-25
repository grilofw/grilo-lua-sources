
-- libquvi-scripts
-- Copyright (C) 2015  quvi project
--
-- This file is part of libquvi-scripts <http://quvi.sourceforge.net/>.
--
-- This library is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This library is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this library; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
-- 02110-1301  USA
--

local Imvdb = {} -- Utility functions unique to this script.

-- Identify the script.
function ident(qargs)
    return {
      can_parse_url = Imvdb.can_parse_url(qargs),
      domains = table.concat({'imvdb.com'}, ',')
  }
end

-- Query available formats.
function query_formats(self)
    self.formats = 'default'
    return self
end

-- Parse media URL.
function parse(qargs)
    local p = quvi.http.fetch(qargs.input_url).data

    qargs.goto_url = p:match('FI.video_source_url = "(.-)"')
                   or error("no match: source URL")

    return qargs
end

--
-- Utility functions
--

function Imvdb.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http?$')
       and t.host   and t.host:lower():match('imvdb%.com$')
       and t.path   and t.path:lower():match('^/video/.-/.-')
  then
    return true
  else
    return false
  end
end

-- vim: set ts=4 sw=4 tw=72 expandtab:
