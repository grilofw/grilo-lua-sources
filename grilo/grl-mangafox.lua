--[[
 * Copyright (C) 2015 Victor Toso
 *
 * Contact: Victor Toso <me@victortoso.com>
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

MANGAFOX_URL       = 'http://mangafox.me/'
MANGAFOX_BROWSE    = MANGAFOX_URL .. "directory/%d.htm?%s"

---------------------------
-- Source initialization --
---------------------------
source = {
  id = "grl-mangafox-lua",
  name = "Mangafox",
  description = "A source for browsing mangas",
  supported_keys = { "id", "title", "thumbnail", "url", "description", "rating",
                     "author", "artist", "genre" },
  supported_media = 'image',
  tags = { 'comics', 'net:internet' }
}

categories = {
    { name = "Alphabetical", id = "az" },
    { name = "Popularity", id = "" },
    { name = "Rating", id = "rating" },
    { name = "Latests Chapters", id = "latest" },
}

mangafox_page_size = 44

------------------
-- Source utils --
------------------

function grl_source_browse(media_id)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  -- current page of browsing (starting in 1)
  local page = (skip / mangafox_page_size) + 1
  -- media to skip in the current page
  local page_skip = (skip % mangafox_page_size)

  -- browsing root of directory
  if not media_id then
    mangafox_browse_root ()
    return
  end

  grl.debug ("media-id: " .. media_id)

  -- browsing a manga
  if media_id:match(MANGAFOX_URL) then
    MANGAFOX_BROWSE_MATCH_IMAGES = "c%d+/%d+.html$"
    MANGAFOX_BROWSE_MATCH_CHAPTERS = "/Mangafox/Volume.-$"

    if media_id:match(MANGAFOX_BROWSE_MATCH_IMAGES) then
      grl.fetch(media_id, "mangafox_browse_images_cb")
    elseif media_id:match(MANGAFOX_BROWSE_MATCH_CHAPTERS) then
      local url = media_id:match("(.-)" .. MANGAFOX_BROWSE_MATCH_CHAPTERS)
      grl.fetch(url, "mangafox_browse_chapters_cb")
    else
      grl.fetch(media_id, "mangafox_browse_volumes_cb")
    end
    return
  end

  -- browsing in one of the categories
  for _, cat in ipairs(categories) do
    local urls = {}
    local found = media_id:find(cat.name)

    if found then
      while count > 0 do
        local url = string.format(MANGAFOX_BROWSE, page, cat.id)
        grl.debug ("Fetching URL: " .. url .. " (page: " .. page .. " cat: " .. cat.name .. ")")
        table.insert(urls, url)
        count = count - page_skip
        page_skip = mangafox_page_size
        page = page + 1
      end
      grl.fetch(urls, "mangafox_browse_category_fetch_cb")
      return
    end
  end

  grl.warning ("Fail to browse: " .. media_id)
  grl.callback()
end

------------------------
-- Callback functions --
------------------------
function mangafox_fetch_images_cb(feeds)
  local viewer_match = '<div id="viewer">(.-)</div>'
  local image_match = '<img src="(.-)"'
  local ret = false

  for i, feed in ipairs(feeds) do
    local image = feed:match(viewer_match)
    image = (image) and image:match(image_match) or nil
    if image then
      local media = {}
      media.type = 'image'
      media.url = image
      grl.callback (media, #feeds - i)
      ret = true
    else
      grl.warning("Fail to parse image at html")
    end
  end

  if ret == false then
    grl.callback ()
  end
end

function mangafox_browse_images_cb(feed)
  local base_url = grl.get_options("media-id")
  local imglist_match = '<select onchange=.->(.-)</select>'
  local img_id_match = '<option value="(.-)"'
  local urls = {}
  local imglist

  -- Count and Skip are ignored at this point, the source
  -- will return all the images of the manga in the right
  -- order

  imglist = feed:match(imglist_match)
  if not imglist then
      grl.warning("Can't extract list of images from: " .. grl.get_options("media-id"))
      grl.debug("Feed:\n'" .. feed .. "'\n")
      grl.callback()
      return
  end

  for id in imglist:gmatch(img_id_match) do
    if tonumber(id) ~= 0 then
      local url
      url = base_url:gsub("%d+%.html", id .. ".html")
      urls[#urls + 1] = url
    end
  end
  grl.fetch(urls, "mangafox_fetch_images_cb")
end

function mangafox_browse_chapters_cb(feed)
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local media_id = grl.get_options("media-id")
  local volume_name = media_id:match(".-/Mangafox/(.-)$")
  local volume_match_list = '<div id="chapters".->(.-)<script'
  local volume_match_name = '<h3 class="volume">'.. volume_name .. '<span>(.+)'

  -- find the right volume
  feed = feed:match(volume_match_list)
  feed = feed:match(volume_match_name)

  local chlist_match = '<ul class="chlist".->(.-)</ul>'
  local ch_match = '<li>(.-)</li>'
  local ch_publication_match = '<span class="date">(.+)</span>'
  local ch_url_match = '<a href="(.-)"'
  local ch_title_match = '<a href=.-class="tips">(.-)</a>'
  local chapterlist

  chapterlist = feed:match(chlist_match)
  if not chapterlist then
      grl.warning("Can't extract list of mangas from: " .. grl.get_options("media-id"))
      grl.debug("Feed:\n" .. feed .. "\n")
      grl.callback()
      return
  end

  for ch in chapterlist:gmatch(ch_match) do
    if not skip or skip == 0 then
      local media = {}
      media.type = "box"
      media.title = ch:match(ch_title_match)
      media.id = ch:match(ch_url_match)
      --[[ TODO: a valid ISO-8601 date
      media.publication_date = ch:match(ch_publication_match)
      --]]
      count = count - 1
      grl.callback(media, count)

      if count == 0 then
        return
      end
    else
      skip = skip - 1
    end
  end
  grl.callback()
end

-- Possibilities of mangafox are:
-- > get all chapters of manga
-- > get all volumes of manga
function mangafox_browse_volumes_cb(feed)
  local media_id = grl.get_options("media-id")
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local volume_match_list = '<div id="chapters".->(.-)<script'
  local volume_match = '<h3 class="volume">(.-)</h3>'
  local volume_match_name = '(.-)<span>'
  local volume_match_chaps = '<span>(.-)</span>'

  -- manga information that is available
  local manga_info = feed:match('<table>(.-)</table>')
  local author = manga_info:match('/search/author/.->(.-)</a>')
  local artist = manga_info:match('/search/artist/.->(.-)</a>')
  local description = feed:match('<p class="summary">(.-)</p>')
  description = description:gsub("<br />", "")

  for list in feed:gmatch(volume_match_list) do
    grl.debug ("list!")
    for volume in list:gmatch(volume_match) do
      if not skip or skip == 0 then
        local media = {}
        local name = volume:match(volume_match_name)
        local chaps = volume:match(volume_match_chaps)
        media.type = "box"
        media.id = media_id .. "Mangafox/" .. name
        media.title = name .. " (" .. chaps .. ")"
        media.author = author
        media.artist = artist
        media.description = description

        count = count - 1
        grl.callback(media, count)

        if count == 0 then
          return
        end
      else
        skip = skip - 1
      end
    end
  end
  grl.callback()
end

-- Return the mangas of selected category
function mangafox_browse_category_fetch_cb(feeds)
  local count = grl.get_options("count")
  local mangalist_match = '<div id="mangalist">.-<ul class="list">(.-)<div class="clear">'
  --local manga_match = '<div class="manga_text">(.-)</div>'
  local manga_match = '<li>(.-)</li>'
  local manga_match_image = '<img.-src="(.-)"'
  local manga_match_title = '<a class="title".->(.-)</a>'
  local manga_match_url = '<a class="title" href="(.-)"'
  local manga_match_genre = '<p class="info" title="(.-)">'
  local manga_match_rating = '<span class="rate">(.-)</span>'

  for _, feed in ipairs(feeds) do
    local mangalist = feed:match(mangalist_match)
    for manga in mangalist:gmatch(manga_match) do
      local genre
      local media = {}
      media.type = "box"
      media.id = manga:match(manga_match_url)
      media.thumbnail = manga:match(manga_match_image)
      media.title = manga:match(manga_match_title)
      media.rating = manga:match(manga_match_rating)
      genres = manga:match(manga_match_genre)
      media.genre = {}
      for genre in genres:gmatch("%a+") do
        media.genre[#media.genre + 1] = genre
      end
      count = count - 1
      grl.callback(media, count)

      if count == 0 then
        return
      end
    end
  end
  grl.callback()
end

-------------
-- Helpers --
-------------
function mangafox_browse_root ()
  local count = grl.get_options("count")
  local skip = grl.get_options("skip")
  local num = #categories - skip
  num = (count < num) and count or num

  if num <= 0 then
    grl.warning ("Skip of ".. skip .. " is more then available media")
    grl.callback()
    return
  end

  for i = 1, num, 1 do
    local media = {}

    media.type = "box"
    media.id = categories[i].name
    media.title = categories[i].name
    grl.callback(media, num-i)
  end
end
