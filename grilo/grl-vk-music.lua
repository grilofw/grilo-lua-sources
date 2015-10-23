--[[
 * Copyright (C) 2015 George Sedov
 *
 * Contact: George Sedov <radist.morse@gmail.com>
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
------- Constants ---------
---------------------------

local VK_API_VER = "5.37"
local URL_VK_BASE = "https://api.vk.com/method/"

local URL_VK_SEARCH                   = URL_VK_BASE.."audio.search?format=json&q=%s&count=%d&offset=%d&access_token=%s&v="..VK_API_VER

local URL_VK_BROWSE                   = URL_VK_BASE.."audio.get?format=json&count=%d&offset=%d&access_token=%s&v="..VK_API_VER
local URL_VK_BROWSE_FRIEND            = URL_VK_BASE.."audio.get?format=json&owner_id=%s&count=%d&offset=%d&access_token=%s&v="..VK_API_VER
local URL_VK_BROWSE_ALBUM             = URL_VK_BASE.."audio.get?format=json&owner_id=%s&album_id=%s&count=%d&offset=%d&access_token=%s&v="..VK_API_VER

local URL_VK_BROWSE_FRIEND_LIST       = URL_VK_BASE.."friends.get?format=json&fields=nickname&count=%d&offset=%d&access_token=%s&v="..VK_API_VER

local URL_VK_BROWSE_ALBUM_LIST        = URL_VK_BASE.."audio.getAlbums?format=json&count=%d&offset=%d&access_token=%s&v="..VK_API_VER
local URL_VK_BROWSE_FRIEND_ALBUM_LIST = URL_VK_BASE.."audio.getAlbums?format=json&owner_id=%s&count=%d&offset=%d&access_token=%s&v="..VK_API_VER


---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-vk-music",
  goa_account_provider = "vk",
  goa_account_feature = "music",
  name = "VK Music",
  description = "Search and listen music from VK.com",
  supported_keys = { "id", "artist", "duration", "title", "url" },
  supported_media = "audio",
  tags = { "music", "net:internet" },
  icon = 'resource:///org/gnome/grilo/plugins/guardian-eyewitness/grilo/guardian-eyewitness.png'
}

local oauth2_token = ""

function grl_source_init ()

  oauth2_token = grl.goa_access_token ()

  if (not oauth2_token) then
    return false
  end

  return true
end

------------------
-- Source utils --
------------------

function grl_source_browse (media, options, callback)
  local skip = options ("skip")
  local count = options ("count")

  if (not media) or (not media.id) then
    if (skip == 0 and count >= 1) then
      local media = {}
      media.type = "box"
      media.id = "myself"
      media.title = "My music"

      callback (media, 1)
    end
    if (skip <= 1 and skip + count >= 2) then
      local media = {}
      media.type = "box"
      media.id = "friends"
      media.title = "My friends' music"
      callback (media, 0)
    end
    if (skip >= 2) then
      callback ()
    end
  else
    local media_id = split (media.id, "_")
    local num = #media_id
    local first_result = nil
    local vk_http_browse = nil
    local my_callback = nil
    if (num == 1 and media_id[1] == "myself") then
      if (skip == 0) then
        first_result = {}
        first_result.type = "box"
        first_result.id = "myself_allmusic"
        first_result.title = "All music"
        count = count - 1
      else
        skip = skip - 1
      end
      vk_http_browse = string.format (URL_VK_BROWSE_ALBUM_LIST,
                                      count,
                                      skip,
                                      oauth2_token)
      my_callback = vk_albums_cb
    end

    if (num == 1 and media_id[1] == "friends") then
      vk_http_browse = string.format (URL_VK_BROWSE_FRIEND_LIST,
                                      count,
                                      skip,
                                      oauth2_token)
      my_callback = vk_friends_cb
    end

    if (num == 2 and media_id[1] == "friend") then
      if (skip == 0) then
        first_result = {}
        first_result.type = "box"
        first_result.id = "friend_"..media_id[2].."_allmusic"
        first_result.title = "All music"
        count = count - 1
      else
        skip = skip - 1
      end
      vk_http_browse = string.format (URL_VK_BROWSE_FRIEND_ALBUM_LIST,
                                      media_id[2],
                                      count,
                                      skip,
                                      oauth2_token)
      my_callback = vk_albums_cb
    end

    if (num == 2 and media_id[1] == "myself" and media_id[2] == "allmusic") then
      vk_http_browse = string.format (URL_VK_BROWSE,
                                      count,
                                      skip,
                                      oauth2_token);
      my_callback = vk_audio_cb
    end

    if (num == 3 and media_id[1] == "friend" and media_id[3] == "allmusic") then
      vk_http_browse = string.format (URL_VK_BROWSE_FRIEND,
                                      media_id[2],
                                      count,
                                      skip,
                                      oauth2_token);
      my_callback = vk_audio_cb
    end

    if (num == 4 and media_id[1] == "friend" and media_id[3] == "album") then
      vk_http_browse = string.format (URL_VK_BROWSE_ALBUM,
                                      media_id[2],
                                      media_id[4],
                                      count,
                                      skip,
                                      oauth2_token);
      my_callback = vk_audio_cb
    end

    if (vk_http_browse) then
      grl.fetch (vk_http_browse,
                 function (data, callback)
                   my_callback (data, callback, first_result)
                 end,
                 {},
                 callback)
    else
      -- TODO: error handling
      print ("[grl-lua-vk]incorrect box ID: "..table.concat(media_id, "_"))
      callback ()
    end
  end

end

function grl_source_search (query, options, callback)

  vk_http_search = string.format (URL_VK_SEARCH,
                                  grl.encode(query),
                                  options ("count"),
                                  options ("skip"),
                                  oauth2_token)

  grl.fetch (vk_http_search, vk_audio_cb, {}, callback)
end

------------------------
-- Callback functions --
------------------------

function vk_friends_cb (results, callback, first_result)
  local json = {}
  json = grl.lua.json.string_to_table (results)
  if (json.error) then
    -- TODO: error handling
    print ("some error")
  end

  if (json.response) then
    if (first_result) then
      callback (first_result, -1)
    end
    for key, item in pairs (json.response.items) do
      local media = {}
      media.type = "box"
      media.id = "friend_"..item.id
      media.title = item.first_name.." "..item.last_name
      callback (media, -1)
    end
  end

  callback ()
end

function vk_albums_cb (results, callback, first_result)
  local json = {}
  json = grl.lua.json.string_to_table (results)
  if (json.error) then
    -- TODO: error handling
    print ("some error")
  end

  if (json.response) then
    if (first_result) then
      callback (first_result, -1)
    end
    for key, item in pairs (json.response.items) do
      local media = {}
      media.type = "box"
      media.id = "friend_"..item.owner_id.."_album_"..item.id
      media.title = item.title
      callback (media, -1)
    end
  end

  callback ()
end

function vk_audio_cb (results, callback, first_result)
  local json = {}
  json = grl.lua.json.string_to_table (results)
  if (json.error) then
    -- TODO: error handling
    print ("some error")
  end

  if (json.response) then
    if (first_result) then
      callback (first_result, -1)
    end
    for key, item in pairs (json.response.items) do
      item.type = "audio"
      item.id = "friend_"..item.owner_id.."_audio_"..item.id
      callback (item, -1)
    end
  end

  callback ()
end

-------------
-- Helpers --
-------------

function split (inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t={} ; i=1
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end
