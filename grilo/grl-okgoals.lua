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

OKGOALS_URL               = 'http://www.okgoals.com/'
OKGOALS_START_FROM_URL    = 'http://www.okgoals.com/page-start_from_%s_archive_.html'
OKGOALS_MATCH_URL         = 'http://www.okgoals.com/%s'

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-okgoals-lua",
  name = "OKGoals",
  description = "A source for browsing football match highlights from OKGoals",
  supported_keys = { "id", "thumbnail", "title", "url", "mime-type", "external-url" },
  supported_media = 'video',
  auto_split_threshold = 33,
  tags = { 'news', 'sport', 'net:internet' }
}

------------------
-- Source utils --
------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local urls = {}

  -- A specific match?
  if media_id then
    local url = string.format(OKGOALS_MATCH_URL, media_id)
    grl.fetch(url, "okgoals_fetch_match_cb")
    return
  end

  if skip == 0 then
    grl.fetch(OKGOALS_URL, "okgoals_fetch_cb")
  else
    local url = string.format(OKGOALS_START_FROM_URL, skip)
    grl.fetch(url, "okgoals_fetch_cb")
  end
end

------------------------
-- Callback functions --
------------------------

function okgoals_fetch_cb(results)
  local count = grl.get_options("count")

  results = results:match('<div class="listajogos">(.-)<div class="wpnavi">')
  for line in results:gmatch('(<a href=.-)</div>') do
    local media = {}

    media.type = 'box'
    media.id = line:match('href="(match%-highlights%-.-)">')
    media.title = line:match(' %- (.-)</a>')
    -- Replace tabs with spaces in title
    media.title = media.title:gsub("\t", " ")

    grl.callback(media, -1)
  end

  grl.callback()
end

function okgoals_fetch_match_cb(results)
  local section = results:match('class="contentjogos"(.-)<div class="sidebar%-divider2">')

  -- YouTube embed, such as http://www.okgoals.com/match-highlights-1424889384---49
  if section:match('src="http://www%.youtube%.com') then
    local media = {}
    media.type = 'video'
    media.title = 'Highlights'
    media.external_url = section:match('src="(http://www%.youtube%.com/embed/.-)"')
    media.id = section:match('src="http://www%.youtube%.com/embed/(.-)"')
    grl.callback(media, -1)
  end

  for video in section:gmatch('>(.-<br.-<script data%-config=".-")') do
    local title, pw_url = video:match('(.-)<script data%-config="(.-)"')

    title = title:gsub("%b<>", "")
    title = title:gsub("\n", "")
    title = grl.unescape(title)

    local mp4_url, thumb_url, id = process_url(pw_url)
    if mp4_url then
      local media = {}
      media.type = 'video'
      media.title = title
      media.id = id
      media.url = mp4_url
      media.thumbnail = thumb_url

      grl.callback(media, -1)
    end
  end

  grl.callback()
end

-------------
-- Helpers --
-------------

function process_url(pw_url)

  local hostid, videoid = pw_url:match('http://config.playwire.com/(%d-)/videos/v2/(%d-)/zeus.json')
  if not hostid or not videoid then
    return nil, nil, nil
  end

  local url = 'http://cdn.phoenix.intergi.com/' .. hostid .. '/videos/' .. videoid .. '/video-sd.mp4?hosting_id=' .. hostid
  local thumb_url = 'http://cdn.phoenix.intergi.com/' .. hostid .. '/videos/' .. videoid .. '/poster_0000.png'
  local id = hostid .. '-' .. videoid

  return url, thumb_url, id
end
