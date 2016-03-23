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
  id = "grl-hotmovies",
  name = "hotmovies",
  description = "HotMovies.com",
  supported_keys = { "thumbnail", 'studio', 'director', 'duration', 'description', 'external-url', 'performer', 'keyword' },
  supported_media = 'video',
  resolve_keys = {
    ["type"] = "video",
    required = { "title" },
  },
  tags = { 'adult', 'net:internet', 'net:plaintext' }
}

------------------
-- Source utils --
------------------

HOTMOVIES_DEFAULT_QUERY = "http://www.hotmovies.com/search.php?words=%s&search_in=video_title"

---------------------------------
-- Handlers of Grilo functions --
---------------------------------

function grl_source_resolve()
  local url, req
  local title

  req = grl.get_media_keys()
  if not req or not req.title then
    grl.callback()
    return
  end

  -- Series don't apply
  if req.show then
    grl.callback()
    return
  end

  -- Only handle ASCII, the site falls over for anything else
  if not is_ascii(req.title) then
    grl.callback()
    return
  end
  -- title = "Bobbi's+World"
  -- title = '1 In The Pink 1 In The Stink #7'
  title = grl.encode(req.title)
  url = string.format(HOTMOVIES_DEFAULT_QUERY, title)
  grl.debug ("Fetching search page " .. url)
  grl.fetch(url, fetch_results_cb)
end

---------------
-- Utilities --
---------------

function is_ascii(str)
  -- From http://stackoverflow.com/questions/24190608/lua-string-byte-for-non-ascii-characters
  for c in str:gmatch("[\0-\x7F\xC2-\xF4][\x80-\xBF]*") do
    if #c >= 2 then
      return false
    end
  end

  return true
end

function fetch_results_cb(results)
  if results and
    not results == '' and
    not results:find('Your search resulted in 0 matches') and
    not results:find('You can search names of stars, titles of movies, directors, specific niches or fetishes, studios etc%.') then
      local id = results:match('divModalScenePreview_(.-)"')
      local url = 'http://www.hotmovies.com/video/' .. id
      grl.debug ("Fetching movie page " .. url .. " for ID " .. id)
      grl.fetch(url, fetch_page_cb)
  else
    grl.callback()
  end
end

function fetch_page_cb(page)
  local media = {}

  media.thumbnail = page:match('id="cover" src="(.-)"')

  media.studio = page:match('itemprop="productionCompany".-><span.->(.-)</span>')
  media.director = page:match('itemprop="director".-><span.->(.-)</span>')

  -- Duration
  local time = page:match('datetime="PT(.?.?H.?.?M.?.?S)"')
  if not time then
    time = page:match('datetime="PT(.?.?H.?.?M)"')
  end
  if not time then
    time = page:match('datetime="PT(.?.?H)"')
  end

  if time then
    hours = time:match('(.-)H') or '0'
    minutes = time:match('H(.-)M') or '0'
    seconds = time:match('M(.-)S') or '0'
    media.duration = tonumber(tonumber(hours) * 3600 + tonumber(minutes) * 60 + tonumber(seconds))
  end

  -- Description
  local encoded_desc = page:match('var descfullcontent = "(.-)"')
  if not encoded_desc then
    encoded_desc = page:match('class="video_description" itemprop="description">(.-)</div>')
  end
  encoded_desc = encoded_desc:gsub("%b<>", "")
  encoded_desc = encoded_desc:gsub("^%s*(.-)%s*$", "%1")
  media.description = grl.decode(encoded_desc)

  -- External URL
  media['external-url'] = page:match('<link rel="canonical" href="(.-)"/>')

  media.performer = {}
  for actor in page:gmatch('itemprop="actor" itemscope itemtype="http://schema%.org/Person"><span itemprop="name">(.-)</span>') do
    table.insert(media.performer, actor)
  end

  local categories = page:match('<div class="categories">(.-)</div>')
  if categories then
    media.keyword = {}
    for keyword in categories:gmatch('rel="tag">(.-)</a>') do
      table.insert(media.keyword, keyword)
    end
  end

  media.creation_date = page:match('itemprop="copyrightYear">(.-)</span>')
  media.tmdb_poster = page:match('boxcover%.php%?img=(.-)&')

  -- box cover
  -- $('#full_boxcover').jqm({ajax:'http://www.hotmovies.com/boxcover.php?img=http://imgcover-2.hotmovies.com/image2/large/202/202903.large.1.jpg&add_close_icon=1&add_guest_form=1',modal:true});
  --

  grl.callback(media, 0)
end
