
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

local FranceInter = {} -- Utility functions unique to this script.

-- Identify the script.
function ident(qargs)
    return {
      can_parse_url = FranceInter.can_parse_url(qargs),
      domains = table.concat({'franceinter.fr'}, ',')
  }
end

-- Query available formats.
function query_formats(self)
    self.formats = 'default'
    return self
end

-- Parse media URL.
function parse(qargs)
    qargs.id = qargs.input_url:match('/player/reecouter%?play=(%d+)')
                  or error("no match: media ID")

    local p = quvi.http.fetch(qargs.input_url).data

    local section = p:match('<div id="emission"  class="current">(.-)<div class="small">')
                  or error('no match: current section')

    local subtitle = section:match('class="title diffusion"><span class="roll_overflow">(.-)</span>')
                  or error('no match: subtitle')
    local title = section:match('<span class="title emission">(.-)</span>')
                  or error('no match: title')
    qargs.title = title .. " — " .. subtitle

    qargs.thumb_url =
        'http://franceinter.fr/' .. section:match('<img src="(.-)" .- class="illus"/>') or ''

    -- FIXME Link back to description page?
    -- local U = require 'quvi/util'
    -- local more_info_url = U.unescape (p:match('u=(http.-)&amp;')) or ''

    qargs.streams = FranceInter.iter_streams(p)

    return qargs
end

--
-- Utility functions
--

function FranceInter.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and t.scheme:lower():match('^http?$')
       and t.host   and t.host:lower():match('franceinter%.fr$')
       and t.path   and t.path:lower():match('^/player/reecouter')
  then
    return true
  else
    return false
  end
end

function FranceInter.iter_streams(p)
  local U = require 'quvi/util'
  local u = U.unescape (p:match('urlAOD=(sites.-)&'))
                or error("no match: media stream URL")

  local S = require 'quvi/stream'
  return {S.stream_new('http://franceinter.fr/' .. u)}
end


-- vim: set ts=4 sw=4 tw=72 expandtab:
