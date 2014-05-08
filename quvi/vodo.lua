
-- libquvi-scripts
-- Copyright (C) 2014  quvi project
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

local Vodo = {} -- Utility functions unique to this script.

-- Identify the script.
function ident(qargs)
    return {
      can_parse_url = Vodo.can_parse_url(qargs),
      domains = table.concat({'vodo.net'}, ',')
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

    qargs.id = p:match('href="/download/(%d+)"')
                  or error("no match: media ID")

    local download_url = 'http://vodo.net/download/torrent/' .. qargs.id
    local d = quvi.http.fetch(download_url).data

    qargs.streams = Vodo.iter_streams(d)

    qargs.title = p:match('property="og:title" content="(.-)"')

    qargs.thumb_url =
        'http://vodo.net' .. p:match('<div id="trailer">%s-<img src="(.-)"') or ''

    return qargs
end

--
-- Utility functions
--

function Vodo.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http?$')
       and t.host   and t.host:lower():match('vodo%.net$')
  then
    return true
  else
    return false
  end
end

function Vodo.iter_streams(d)
  local u = d:match('id="do_download" href="(.-)"')
  local S = require 'quvi/stream'
  return {S.stream_new('torrent+http://vodo.net/' .. u)}
end


-- vim: set ts=4 sw=4 tw=72 expandtab:
