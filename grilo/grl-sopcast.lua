--[[
 * Copyright (C) 2015 Bastien Nocera
 *
 * Contact: Bastien Nocera <hadess@hadess.net>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA
 *
--]]

SOPCAST_URL    = 'http://www.sopcast.com/gchlxml'

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-sopcast-lua",
  name = "SopCast",
  description = "A source for browsing TV channels from SopCast.com",
  supported_keys = { "id", "thumbnail", "title", "url", "mime-type", "external-url" },
  supported_media = 'video',
  tags = { 'tv', 'country:zh', 'net:internet', 'net:plaintext' },
  icon = 'resource:///org/gnome/grilo/plugins/sopcast/grilo/sopcast.png'
}

-- Global table to store parse results
cached_xml = nil

------------------
-- Source utils --
------------------

function grl_source_browse()
  local skip = grl.get_options("skip")
  local count = grl.get_options("count")

  -- Make sure to reset the cache when browsing again
  if skip == 0 then
    cached_xml = nil
  end

  if cached_xml then
    parse_results(cached_xml)
  else
    local url = SOPCAST_URL
    grl.debug('Fetching URL: ' .. url .. ' (count: ' .. count .. ' skip: ' .. skip .. ')')
    grl.fetch(url, sopcast_fetch_cb)
  end
end

------------------------
-- Callback functions --
------------------------

function sopcast_fetch_cb(results)
  if not results then
    grl.warning('Failed to fetch XML file')
    grl.callback()
    return
  end

  cached_xml = grl.lua.xml.string_to_table(results)
  print (grl.lua.inspect(cached_xml))
  parse_results(cached_xml)
end

function parse_results(results)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local cont

  for i, group in pairs(results.group) do
    if group.channel.id then
      count, skip, cont = parse_channel(group.channel, count, skip)
    else
      for j, channel in pairs(group.channel) do
        count, skip, cont = parse_channel(channel, count, skip)
      end
    end

    if not cont then return end
  end

  if count ~= 0 then
    grl.callback()
  end
end

function parse_channel(channel, count, skip)
  local media = {}

  -- print (grl.lua.inspect (channel))

  media.type = 'video'
  media.id = channel.id
  media.title = channel.name.xml
  media.genre = channel.class.en
  media.url = channel.sop_address.item.xml

  if skip > 0 then
    skip = skip - 1
  else
    count = count - 1
    grl.callback(media, count)
    if count == 0 then
      return count, skip, false
    end
  end

  return count, skip, true
end
