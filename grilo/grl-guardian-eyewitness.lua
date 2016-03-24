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

GUARDIAN_EYEWITNESS_URL = 'http://mobile-apps.guardianapis.com/lists/tag/theguardian/mainsection/eyewitness?page=%d'
DEFAULT_COUNT           = 20

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-guardian-eyewitness-lua",
  name = "The Guardian Eye Witness",
  description = "A source for browsing photos from the Guardian Eye Witness series",
  supported_keys = { "id", "thumbnail", "title", "url", "mime-type", "author", "description", "external-url", "license" },
  supported_media = 'image',
  auto_split_threshold = DEFAULT_COUNT,
  tags = { 'news', 'photos', 'net:internet', 'net:plaintext' },
  icon = 'resource:///org/gnome/grilo/plugins/guardian-eyewitness/grilo/guardian-eyewitness.png'
}

------------------
-- Source utils --
------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local urls = {}

  -- page count starts from 1
  local page = skip / DEFAULT_COUNT + 1
  if page > math.floor(page) then
    local url = string.format(GUARDIAN_EYEWITNESS_URL, math.floor(page))
    grl.debug ("Fetching URL #1: " .. url .. " (page: " .. math.floor(page) .. " starting at: " .. (math.floor(page)) * DEFAULT_COUNT .. " count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)

    url = string.format(GUARDIAN_EYEWITNESS_URL, math.floor(page) + 1)
    grl.debug ("Fetching URL #2: " .. url .. " (page: " .. math.floor(page) + 1 .. " starting at: " .. (math.floor(page) + 1) * DEFAULT_COUNT .. " count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)
  else
    local url = string.format(GUARDIAN_EYEWITNESS_URL, page)
    grl.debug ("Fetching URL: " .. url .. " (page: " .. page .. " starting at: " .. (page - 1) * DEFAULT_COUNT .. " count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)
  end

  grl.fetch(urls, guardian_eyewitness_fetch_cb)
end

------------------------
-- Callback functions --
------------------------

-- return all the media found
function guardian_eyewitness_fetch_cb(results)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")

  local page = skip / DEFAULT_COUNT + 1
  skip = skip - (math.floor(page) -1) * DEFAULT_COUNT

  for i, result in ipairs(results) do
    local json = {}
    json = grl.lua.json.string_to_table(result)

    -- local inspect = require('inspect')
    -- grl.debug (inspect(json.cards))

    if not json or json.stat == "fail" or not json.cards then
      grl.callback()
      return
    end

    for index, item in pairs(json.cards) do
      if skip > 0 then
        skip = skip - 1
      else
        local media = create_media(item.item)
        count = count - 1
        grl.callback(media, count)

        -- Bail out if we've given enough items
        if count == 0 then
          return
        end
      end
    end
  end
end

-------------
-- Helpers --
-------------

function create_url(image, height, width)
  local url = image.urlTemplate
  url = string.gsub(url, '#%{width%}', width)
  url = string.gsub(url, '#%{height%}', height)
  url = string.gsub(url, '#%{quality%}', '60')
  return url
end

function create_media(item)
  local media = {}

  media.type = "image"
  media.id = item.id
  media.title = item.title
  media.mime_type = 'image/jpeg'
  media.external_url = 'http://www.theguardian.com/' .. item.id
  media.url = create_url(item.displayImages[1],
                         item.displayImages[1].height,
                         item.displayImages[1].width)
  media.thumbnail = create_url(item.displayImages[1], '-', '512')
  media.description = item.displayImages[1].altText
  media.license = "Copyright © " .. item.displayImages[1].credit
  media.author = media.license

  return media
end
