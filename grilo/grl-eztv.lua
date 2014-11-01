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
-- https://github.com/popcorn-official/popcorn-api/blob/master/README.md

-- Page number
EZTV_URL = 'http://eztvapi.re/shows/%s?sort=updated'
-- IMDB ID (ttXXXXXXX)
EZTV_DETAILS_URL = 'http://eztvapi.re/show/%s'
-- Page then keywords
EZTV_SEARCH_URL = 'http://eztvapi.re/shows/%s?keywords=%s&sort=updated'

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-eztv",
  name = "EzTV",
  description = "EzTV",
  supported_keys = { 'tmdb-imdb-id', 'rating', 'creation-date', 'modification-date', 'title', 'id', 'url', 'mime-type', 'description', 'season', 'episode', 'show', 'studio', 'thetvdb-banner', 'thetvdb-fanart', 'thetvdb-poster', 'thetvdb-id' },
  supported_media = 'video',
  tags = { 'tv' },
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

  if not media_id then
    local page = skip / count + 1
    if page > math.floor(page) then
      local url = string.format(EZTV_URL, math.floor(page))
      grl.debug ("Fetching URL #1: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
      table.insert(urls, url)

      url = string.format(EZTV_URL, math.floor(page) + 1)
      grl.debug ("Fetching URL #2: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
      table.insert(urls, url)
    else
      local url = string.format(EZTV_URL, page)
      grl.debug ("Fetching URL: " .. url .. " (count: " .. count .. " skip: " .. skip .. ")")
      table.insert(urls, url)
    end

    grl.fetch(urls, "fetch_series_results_cb")
  else
    local url = string.format(EZTV_DETAILS_URL, media_id)
    table.insert(urls, url)
    grl.fetch(urls, "fetch_results_cb")
  end
end

function grl_source_search(text)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local urls = {}

  text = string.gsub(text, " ", "+")

  local page = skip / count + 1
  if page > math.floor(page) then
    local url = string.format(EZTV_SEARCH_URL, math.floor(page), text)
    grl.debug ("Fetching URL #1: " .. url .. " (count: " .. count .. " skip: " .. skip .. " text: " .. text .. ")")
    table.insert(urls, url)

    url = string.format(EZTV_SEARCH_URL, math.floor(page) + 1, text)
    grl.debug ("Fetching URL #2: " .. url .. " (count: " .. count .. " skip: " .. skip .. " text: " .. text .. ")")
    table.insert(urls, url)
  else
    local url = string.format(EZTV_SEARCH_URL, page, text)
    grl.debug ("Fetching URL: " .. url .. " (count: " .. count .. " skip: " .. skip .. " text: " .. text .. ")")
    table.insert(urls, url)
  end

  grl.fetch(urls, "fetch_series_results_cb")
end

---------------
-- Utilities --
---------------

function fetch_series_results_cb(results)
  local count = grl.get_options("count")
  -- FIXME handle skip

  if not results then
    grl.callback()
    return
  end

  local medias = {}

  for i, result in ipairs(results) do
    medias = parse_series_page(result, medias)
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

function parse_series_page(page, medias)
  local json = {}

  json = grl.lua.json.string_to_table(page)
  if not json then
    return medias
  end

  for index, item in pairs(json) do
    -- local inspect = require('inspect')
    -- grl.debug (inspect(item))

    local media = {}

    media.type = 'box'
    media.id = item._id
    if item.images then
      media.thetvdb_banner = item.images.banner
      media.thetvdb_fanart = item.images.fanart
      media.thetvdb_poster = item.images.poster
    end
    media.tmdb_imdb_id = item.imdb_id
    media.modification_date = last_updated
    media.title = item.title
    media.creation_date = item.year
    media.thetvdb_id = item.tvdb_id

    table.insert(medias, media)
  end

  return medias
end

function fetch_results_cb(results)
  local count = grl.get_options("count")
  -- FIXME handle skip

  if not results then
    grl.callback()
    return
  end

  local medias = {}

  for i, result in ipairs(results) do
    medias = parse_page(result, medias)
  end

  -- Sort episodes by update date
  local inspect = require('inspect')
  table.sort(medias, function(a,b) return a.first_aired > b.first_aired end)

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
      media.first_aired = nil
      grl.callback(media, num_results)
    end
  end
end

function parse_page(page, medias)
  local json = {}

  json = grl.lua.json.string_to_table(page)
  if not json or not json.episodes then
    return medias
  end

  for index, item in pairs(json.episodes) do
    -- local inspect = require('inspect')
    -- grl.debug (inspect(item))

    local media = {}

    media.type = 'video'
    media.id = item.tvdb_id
    media.description = item.overview
    media.title = item.title
    media.episode = item.episode
    media.season = item.season
    media.modification_date = os.date("!%Y-%m-%dT%TZ", item.first_aired)
    media.url = item.torrents["0"].url
    media.mime_type = 'application/x-bittorrent'

    -- Used to sort the episodes by recency
    media.first_aired = item.first_aired

    media.show = json.title
    media.studio = json.network
    media.creation_date = json.year
    media.rating = tonumber(json.rating.percentage) / 20

    table.insert(medias, media)
  end

  return medias
end
