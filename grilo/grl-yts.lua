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

-- API Documentation available at:
-- http://yts.to/api

YTS_URL = 'http://yts.to/api/list.json?set=%s&limit=%s'
YTS_SEARCH_URL = YTS_URL .. '&keywords=%s'

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-yts",
  name = "YTS",
  description = "YTS",
  supported_keys = { 'thumbnail', 'genre', 'tmdb-imdb-id', 'rating', 'creation-date', 'external-url', 'title', 'id', 'url', 'mime-type', 'size' },
  supported_media = 'video',
  tags = { 'cinema', 'torrent', 'net:internet' },
  auto_split_threshold = 50
}

------------------
-- Source utils --
------------------

---------------------------------
-- Handlers of Grilo functions --
---------------------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local urls = {}

  local page = skip / count + 1
  if page > math.floor(page) then
    local url = string.format(YTS_URL, math.floor(page), count)
    grl.debug ("Fetching URL #1: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)

    url = string.format(YTS_URL, math.floor(page) + 1, count)
    grl.debug ("Fetching URL #2: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)
  else
    local url = string.format(YTS_URL, page, count)
    grl.debug ("Fetching URL: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
    table.insert(urls, url)
  end

  grl.fetch(urls, "fetch_results_cb")
end

function grl_source_search(text)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local urls = {}

  text = string.gsub(text, " ", "+")

  local page = skip / count + 1
  if page > math.floor(page) then
    local url = string.format(YTS_SEARCH_URL, math.floor(page), count, text)
    grl.debug ("Fetching URL #1: " .. url .. " (count: " .. count .. " skip: " .. skip .. " text: " .. text .. ")")
    table.insert(urls, url)

    url = string.format(YTS_SEARCH_URL, math.floor(page) + 1, count, text)
    grl.debug ("Fetching URL #2: " .. url .. " (count: " .. count .. " skip: " .. skip .. " text: " .. text .. ")")
    table.insert(urls, url)
  else
    local url = string.format(YTS_SEARCH_URL, page, count, text)
    grl.debug ("Fetching URL: " .. url .. " (count: " .. count .. " skip: " .. skip .. " text: " .. text .. ")")
    table.insert(urls, url)
  end

  grl.fetch(urls, "fetch_results_cb")
end

---------------
-- Utilities --
---------------

function fetch_results_cb(results)
  local count = grl.get_options("count")

  if not results then
    grl.callback()
    return
  end

  local medias = {}

  for i, result in ipairs(results) do
    medias = parse_page(result, medias)
  end

  local num_results = #medias
  if num_results > count then
    num_results = count
  end
  if num_results == 0 then
    grl.callback()
    return
  end

  -- Send out the results
  for i, media in ipairs(medias) do
    if count > 0 then
      num_results = num_results - 1
      count = count - 1
      grl.debug ('Sending out media ' .. media.id .. ' (left: ' .. num_results .. ')')
      grl.callback(media, num_results)
    end
  end
end

function parse_page(page, medias)
  local json = {}

  json = grl.lua.json.string_to_table(page)
  if not json or not json.MovieList then
    return medias
  end

  for index, item in pairs(json.MovieList) do
    -- local inspect = require('inspect')
    -- print (inspect(item))

    if item.State == 'OK' then
      local media = {}

      media.thumbnail = item.CoverImage
      media.genre = item.Genre
      media.tmdb_imdb_id = item.ImdbCode
      media.rating = item.MovieRating
      media.title = item.MovieTitleClean
      media.id = item.MovieID
      media.external_url = item.MovieUrl
      media.creation_date = item.MovieYear
      media['type'] = 'video'
      media.mime_type = 'application/x-bittorrent'
      -- http:// becomes torrent+http://
      -- https:// becomes torrents+https://
      media.url = 'torrent+' .. item.TorrentUrl
      media.size = item.SizeByte

      -- FIXME include quality info somehow

      table.insert(medias, media)
    end
  end

  return medias
end
