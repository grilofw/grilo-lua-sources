--[[
 * Copyright (C) 2014 Grilo Project
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

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-vodo",
  name = "VODO",
  description = "vodo.com",
  supported_media = 'video',
  supported_keys = { 'thumbnail', 'external-url', 'title', 'id', 'mime-type', 'creation-date', 'director' },
  tags = { 'films', 'torrent', 'net:internet', 'net:plaintext' },
}

---------------------------------
-- Handlers of Grilo functions --
---------------------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")

  if media_id or skip ~= 0 then
    grl.callback()
    return
  end

  grl.fetch('http://vodo.net/films/', 'fetch_front_cb')
end

---------------
-- Utilities --
---------------

ROOT_URL = 'http://vodo.net'

function fetch_front_cb(results)
  if not results then
    grl.warning('Failed to fetch the front page')
    grl.callback()
    return
  end

  local s = results:match('<!%-%- MORE FILMS %-%->(.+)')

  for section in s:gmatch('<div class="sticker">(.-)</div>%s-</li>') do
    local media = {}
    media.title = grl.unescape(section:match('alt="(.-)"'))

    -- FIXME
    -- There's a bunch of films that could actually be downloaded
    -- but haven't been yet, and they wouldn't show up in our list :/
    local can_download = section:match('Downloads</dt>%s-<dd>(.-)</dd>')
    if can_download then
      media.type = 'video'
      media.external_url = ROOT_URL .. section:match('href="(.-)"')
      media.thumbnail = ROOT_URL .. section:match('src="(.-)"')
      media.id = media.thumbnail:match('/work_(%d+)_')
      media.mime_type = 'application/x-bittorrent'
      media.creation_date = section:match('<span class="alt">%((%d+)%)</span>')
      media.director = section:match('Director</dt>%s-<dd>(.-)</dd>')

      -- We don't set a description because there's a better one
      -- on the video's page itself
      -- media.description = section:match('<div class="text">(.-)</div>')
      grl.callback(media, -1)
    else
      print ('Cannot download: ' .. media.title)
    end
  end
  grl.callback()
end
