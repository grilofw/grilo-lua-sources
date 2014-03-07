--[[
 * Copyright (C) 2014 Bastien Nocera
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

GUARDIAN_EYEWITNESS_URL               = 'http://content.guardianapis.com/search?format=json&tag=world/series/eyewitness,type/picture&show-fields=short-url,thumbnail&show-factboxes=photography-tip&show-media=all&show-factbox-fields=pro-tip&show-media-fields=all&page=%s&page-size=%s&order-by=newest&api-key=zsduht84cwvds8kk4xmmcvj5'

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-guardian-eyewitness-lua",
  name = "The Guardian Eye Witness",
  description = "A source for browsing photos from the Guardian Eye Witness series",
  supported_keys = { "id", "thumbnail", "title", "url", "mime-type", "author", "description", "external-url", "license" },
  supported_media = 'image',
  auto_split_threshold = 50,
  tags = { 'news', 'photos' }
}

------------------
-- Source utils --
------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local urls = {}

  local page = skip / count + 1
  if page > math.floor(page) then
    local url = string.format(GUARDIAN_EYEWITNESS_URL, math.floor(page), count)
    grl.debug ("Fetching URL #1: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)

    url = string.format(GUARDIAN_EYEWITNESS_URL, math.floor(page) + 1, count)
    grl.debug ("Fetching URL #2: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)
  else
    local url = string.format(GUARDIAN_EYEWITNESS_URL, page, count)
    grl.debug ("Fetching URL: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)
  end

  grl.fetch(urls, "guardian_eyewitness_fetch_cb")
end

------------------------
-- Callback functions --
------------------------

-- return all the media found
function guardian_eyewitness_fetch_cb(results)
  local count = grl.get_options("count")

  for i, result in ipairs(results) do
    local json = {}
    json = grl.lua.json.string_to_table(result)
    if not json or json.stat == "fail" or not json.response or not json.response.results then
      grl.callback()
      return
    end

    for index, item in pairs(json.response.results) do
      local media = create_media(item)
      count = count - 1
      grl.callback(media, count)
    end

    -- Bail out if we've given enough items
    if count == 0 then
      return
    end
  end
end

-------------
-- Helpers --
-------------

function create_media(item)
  local media = {}

  media.type = "image"
  media.id = item.id
  media.title = item.webTitle
  media.thumbnail = item.fields.thumbnail
  media.mime = 'image/jpeg'
  media.external_url = item.webUrl

  local last_width = 0
  for index, picture in pairs(item.mediaAssets) do
    if tonumber(picture.fields.width) > last_width then
      media.url = picture.fields.secureFile
      media.description = picture.fields.caption
      media.author = picture.fields.photographer
      -- if not media.author then
      --  media.author = picture.fields.credit
      -- end
      media.license = "Copyright © " .. picture.fields.credit
      last_width = tonumber(picture.fields.width)
    end
  end

  return media
end
