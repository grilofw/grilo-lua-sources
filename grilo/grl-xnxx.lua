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

-- Foreword:
-- xnxx.com is listed as the top Adult site on the Internet
-- according to Alexa. It is however just another front-end
-- to XVideos.

source = {
  id = "grl-xnxx",
  name = "xnxx.com / XVideos",
  description = "xnxx.com",
  supported_media = 'video',
  supported_keys = { 'thumbnail', 'duration', 'external-url', 'title', 'id' },
  tags = { 'adult', 'net:internet', 'net:plaintext' },
}

-- The number of items per page for a search
-- eg. search_num['foobar'][10] will give you the number
-- of items in page 10 for search foobar.
search_num_items = {}

-- Ditto for browse
browse_num_items = {}

-- The website, very helpfully, puts a random number of
-- items within a search or browse page. So we'll save
-- a couple of variables to be able to chain calls
operation_data = {}

-- This is a cache for the front page
front_page = nil

------------------
-- Source utils --
------------------

---------------------------------
-- Handlers of Grilo functions --
---------------------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")

  -- Handle the root
  if not media_id then
    if skip > 0 then
      grl.callback()
      return
    end
    if front_page then
      fetch_front_cb(front_page)
    else
      grl.fetch('http://www.xnxx.com/', 'fetch_front_cb')
    end
    return
  end

  if skip ~= 0 then
    page, skip = page_for_skip(false, media_id, skip)
    if page == nil then
      grl.warning('Tried to skip without populating the cache')
      grl.callback()
      return
    end
  else
    page = 0
  end

  local url = get_browse_url(media_id, page)
  grl.debug('Fetching URL: ' .. url .. ' (count: ' .. count .. ' skip: ' .. skip .. ')')
  grl.fetch(url, "fetch_results_cb")

  -- Remember operation details
  operation_data[grl.get_options('operation-id')] = {
    is_search = false,
    text = media_id,
    page = page,
    count = count,
    skip = skip
  }

end

function grl_source_search(text)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")

  text = string.gsub(text, " ", "+")

  if skip ~= 0 then
    page, skip = page_for_skip(true, text, skip)
    if page == nil then
      grl.warning('Tried to skip without populating the cache')
      grl.callback()
      return
    end
  else
    page = 0
  end

  local url = get_search_url(text, page)
  grl.debug('Fetching URL: ' .. url .. ' (count: ' .. count .. ' skip: ' .. skip .. ')')
  grl.fetch(url, "fetch_results_cb")

  -- Remember operation details
  operation_data[grl.get_options('operation-id')] = {
    is_search = true,
    text = text,
    page = page,
    count = count,
    skip = skip
  }
end

---------------
-- Utilities --
---------------

function save_num_items(is_search, text, page, num_items)
  local array
  local name
  if is_search then
    array = search_num_items
    name = 'search'
  else
    array = browse_num_items
    name = 'browse'
  end


  grl.debug('Saving that page ' .. page .. ' of ' .. name .. ' "' .. text .. '" has ' .. num_items .. ' items')
  if array[text] == nil then
    array[text] = {}
  end
  array[text][page + 1] = num_items
end

-- Get the page number we should load
-- to get to the number of items we need
-- to skip
function page_for_skip(is_search, text, skip)
  local page = 0
  local num_items = 0

  local array
  if is_search then
    array = search_num_items
  else
    array = browse_num_items
  end

  grl.debug('Trying to get page for search "' .. text .. '" (skip: ' .. skip .. ')')
  while true do
    if not array[text] then
      return nil
    end
    local page_num_items = array[text][page + 1]
    grl.debug('Page ' .. page .. ' of search "' .. text .. '" has ' .. page_num_items or '' .. ' items (' .. num_items .. ' items so far')
    if page_num_items == nil then
      return nil
    end
    if page_num_items + num_items > skip then
      return page, skip - num_items
    end
    num_items = num_items + page_num_items
    page = page + 1
  end

  return nil, nil
end

XNXX_DEFAULT_QUERY = "http://www.xnxx.com/?k=%s&sort=relevance&durf=allduration&datef=all"

function get_search_url(text, page)
  if page == 0 then
    return string.format(XNXX_DEFAULT_QUERY, text)
  end
  return string.format(XNXX_DEFAULT_QUERY .. '&p=%d', text, page)
end

XNXX_BROWSE_PAGE_ZERO = 'http://www.xnxx.com/c/%s'
XNXX_BROWSE = 'http://www.xnxx.com/c/%d/%s'

function get_browse_url(tag, page)
  if page == 0 then
    return string.format(XNXX_BROWSE_PAGE_ZERO, tag)
  end
  return string.format(XNXX_BROWSE, page, tag)
end

function fetch_results_cb(results)
  local operation_id = grl.get_options('operation-id')
  if not operation_id then
    grl.warning ('Failed to get results for operation-id ' .. operation_id)
    return
  end

  if not results or
      results:find('No video match with this search') then
    operation_data[operation_id] = nil
    grl.callback()
    return
  end

  local op = operation_data[operation_id]
  local medias = parse_page(results)
  local num_results = #medias
  save_num_items(op.is_search, op.text, op.page, num_results)

  -- Send out the results
  for i, media in ipairs(medias) do
    if op.skip > 0 then
      op.skip = op.skip - 1
    else
      op.count = op.count - 1
      grl.callback(media, op.count)
      if op.count == 0 then
        operation_data[operation_id] = nil
        return
      end
    end
  end

  -- We need to fetch another page!
  op.page = op.page + 1

  local url
  if op.is_search then
    url = get_search_url(op.text, op.page)
  else
    url = get_browse_url(op.text, op.page)
  end
  grl.debug('Fetching URL: ' .. url)
  grl.fetch(url, "fetch_results_cb")
end

function parse_page(page)
  local medias = {}

  for item in page:gmatch('(<li><div .-</div>)') do
    media = {}

    media.external_url = item:match('<a href="(.-)"')
    media.id = item:match('/video(.-)/')
    -- Support multiple thumbnails?
    media.thumbnail = item:match('<img src="(.-)"')
    media.title = grl.unescape(item:match('title="(.-)"'))

    minutes = item:match('(%d+) min') or '0'
    seconds = item:match('(%d+) sec') or '0'
    media.duration = tonumber(minutes) * 60 + tonumber(seconds)

    table.insert(medias, media)
  end

  return medias
end

function fetch_front_cb(results)
  if not results then
    grl.warning('Failed to fetch the front page')
    grl.callback()
    return
  end

  if not front_page then
    front_page = results
  end

  local s = results:match('ALL SEX VIDEOS:</b>(.-)<a href="http://www%.xnxx%.com/tags/">')
  if not s then
    grl.warning ('Could not parse the front page')
    grl.callback()
    return
  end

  for id, name  in s:gmatch('<a href="http://www%.xnxx%.com/c/(.-)">(.-)</') do
    grl.debug('Got ID: "' .. id .. '" Name: "' .. name .. '"')

    -- FIXME include tags? uniquify?

    media = {}
    media.type = 'box'
    media.id = id
    media.title = name

    grl.callback(media, -1)
  end
  grl.callback()
end
