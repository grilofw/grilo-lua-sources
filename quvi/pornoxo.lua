
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

local Pornoxo = {} -- Utility functions unique to this script.

-- Identify the script.
function ident(qargs)
    return {
      can_parse_url = Pornoxo.can_parse_url(qargs),
      domains = table.concat({'pornoxo.com'}, ',')
  }
end

-- Query available formats.
function query_formats(self)
    self.formats = 'default'
    return self
end

-- Parse media URL.
function parse(qargs)
    qargs.id = qargs.input_url:match('/videos/(%d+)/')
                  or error("no match: media ID")

    local p = quvi.http.fetch(qargs.input_url).data

    qargs.title = p:match('<h1>(.-)</h1>')
                  or error("no match: media title")

    qargs.thumb_url =
        p:match('poster="(http://.-)" preload="metadata"') or ''

    qargs.streams = Pornoxo.iter_streams(p)

    return qargs
end

--
-- Utility functions
--

function Pornoxo.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http?$')
       and t.host   and t.host:lower():match('pornoxo%.com$')
       and t.path   and t.path:lower():match('^/videos/%d+/')
  then
    return true
  else
    return false
  end
end

function Pornoxo.iter_streams(p)
  local U = require 'quvi/util'
  local u = p:match('<source src="(.-)" type="video/mp4"')
                or error("no match: media stream URL")

  local width, height =
      p:match('width="(%d+)" height="(%d+)" poster="')

  local S = require 'quvi/stream'
  local s = S.stream_new(u)
  s.video.width = width
  s.video.height = height
  s.container = 'video/mp4'
  return {s}
end


-- vim: set ts=4 sw=4 tw=72 expandtab:
