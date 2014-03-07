
-- libquvi-scripts
-- Copyright (C) 2012  quvi project
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

local Xnxx = {} -- Utility functions unique to this script.

-- Identify the script.
function ident(qargs)
    return {
      can_parse_url = Xnxx.can_parse_url(qargs),
      domains = table.concat({'xnxx.com'}, ',')
  }
end

-- Query available formats.
function query_formats(self)
    self.formats = 'default'
    return self
end

-- Parse media URL.
function parse(qargs)
    qargs.id = qargs.input_url:match('/video(%d+)/')
                  or error("no match: media ID")

    local u = 'http://www.xnxx.com/video' .. qargs.id .. '/'
    local p = quvi.http.fetch(u).data

    qargs.title = p:match('<span class="style5"><strong>(.-)</strong>')
                  or error("no match: media title")

    qargs.thumb_url =
        p:match('url_bigthumb=(http://.-)&') or ''

    qargs.streams = Xnxx.iter_streams(p)

    return qargs
end

--
-- Utility functions
--

function Xnxx.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http?$')
       and t.host   and t.host:lower():match('xnxx%.com$')
       and t.path   and t.path:lower():match('^/video%d+/')
  then
    return true
  else
    return false
  end
end

function Xnxx.iter_streams(p)
  local U = require 'quvi/util'
  local u = U.unescape (p:match('flv_url=(http.-)&'))
                or error("no match: media stream URL")

  local S = require 'quvi/stream'
  return {S.stream_new(u)}
end


-- vim: set ts=4 sw=4 tw=72 expandtab:
