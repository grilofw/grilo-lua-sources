
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

local Empflix = {} -- Utility functions unique to this script.

-- Identify the script.
function ident(qargs)
    return {
      can_parse_url = Empflix.can_parse_url(qargs),
      domains = table.concat({'empflix.com'}, ',')
  }
end

-- Query available formats.
function query_formats(self)
    self.formats = 'default'
    return self
end

-- Parse media URL.
function parse(qargs)
    qargs.id = qargs.input_url:match('/videos/.-%-(%d+)%.html')
                  or error("no match: media ID")

    local p = quvi.http.fetch(qargs.input_url).data
    if p:match('Sorry, the movie you requested') then
        error("This movie does not exist")
    end

    local u = p:match('flashvars%.config = escape%("(.-)"')
                  or error("no match: config URL")

    local config = quvi.http.fetch(u).data

    qargs.title = p:match('name="title" value="(.-)"')
                  or error("no match: media title")

    qargs.thumb_url = config:match('<startThumb>(.-)</startThumb>')

    qargs.streams = Empflix.iter_streams(config)

    return qargs
end

--
-- Utility functions
--

function Empflix.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http?$')
       and t.host   and t.host:lower():match('empflix%.com$')
       and t.path   and t.path:lower():match('^/videos/.-%d-.html')
  then
    return true
  else
    return false
  end
end

function Empflix.iter_streams(config)
  local U = require 'quvi/util'
  local u = config:match('<videoLink>(.-)</videoLink>')
                or error("no match: media stream URL")

  local S = require 'quvi/stream'
  local s = S.stream_new(u)
  s.container = 'video/mp4'
  return {s}
end


-- vim: set ts=4 sw=4 tw=72 expandtab:
