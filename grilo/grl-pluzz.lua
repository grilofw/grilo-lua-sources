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

FLUXMAIN_URL               = 'http://webservices.francetelevisions.fr/catchup/flux/flux_main.zip'

-- The list of files that we want to unzip inside
-- the manifest archive
files = {
  'message_FT.json',
  'catch_up_france2.json',
  'catch_up_france3.json',
  'catch_up_france3_regions.json',
  'catch_up_france4.json',
  'catch_up_france5.json',
  'catch_up_franceo.json',
  'catch_up_france1.json'
}

-- The list of channel names depending on which
-- Json file we're parsing
channels = {}
channels['message_FT.json'] = 'Direct'
channels['catch_up_france2.json'] = 'France 2'
channels['catch_up_france3.json'] = 'France 3'
channels['catch_up_france3_regions.json'] = 'France 3 Régions'
channels['catch_up_france4.json'] = 'France 4'
channels['catch_up_france5.json'] = 'France 5'
channels['catch_up_franceo.json'] = 'France Ô'
channels['catch_up_france1.json'] = 'France 1'

-- A cache of the parsed json files
cache_needs_download = true
cache = {}

-- The URI base for videos and images
url_base_images = nil
url_base_videos = nil

---------------------------
-- Source initialization --
---------------------------

-- FIXME Use icon:
-- http://m.static-pluzz.francetv.fr/img/icons/apple-icon-114x114-precomposed-cc2ea7787b276f0a942246183da3a9a3.png

source = {
  id = "grl-pluzz-lua",
  name = "Pluzz (France Télévisions)",
  description = "A source for browsing catch up TV from France Télévisions",
  supported_keys = { "id", "thumbnail", "title", "url", 'genre', 'creation-date' },
  supported_media = 'video',
  tags = { 'tv' }
}

------------------
-- Source utils --
------------------

function grl_source_browse(media_id)
  if cache_needs_download then
    grl.unzip('http://webservices.francetelevisions.fr/catchup/flux/flux_main.zip',
              files, "pluzz_fetch_cb")
  else
    grl.debug('Using cached version of the manifest')
    process_op()
  end
end

------------------------
-- Callback functions --
------------------------

-- return all the media found
function pluzz_fetch_cb(results)
  cache_needs_download = false

  -- Parse all the results
  for i, result in ipairs(results) do
    local name = files[i]
    local json = {}

    json = grl.lua.json.string_to_table(result)
    if not json or json.state == 'fail' then
      grl.warning ('Failed to parse ' .. name)
      -- Sad face
      cache_needs_download = true
    else
      cache[name] = json

      if name == 'message_FT.json' then
        url_base_images = json.configuration.url_base_images
        url_base_videos = json.configuration.url_base_videos
      end
    end
  end

  if cache_needs_download then
    grl.callback()
  else
    process_op()
  end
end

function process_op()
  local op_type = grl.get_options('type')
  if op_type == 'browse' then
    local skip = grl.get_options("skip")
    if skip == 0 then
      browse_real(grl.get_options('media-id'))
    end
  end

  -- FIXME other op types
end

function browse_real(media_id)
  -- Handle the root
  if not media_id then
    for i, name in ipairs(files) do
      local media = {}
      media.id = name
      media.type = 'box'
      media.title = channels[name]
      grl.callback(media, -1)
    end
    grl.callback()
  end

  if media_id == 'message_FT.json' then
    for i, item in ipairs(cache[media_id].configuration.directs) do
      local media = {}
      media.id = item.nom
      media.type = 'video'
      media.title = item.nom -- FIXME
      -- TODO maybe use the iOS v5 versions when that's supported?
      media.url = item.video_ipad
      grl.callback(media, -1)
    end
    grl.callback()
  end

  if media_id and media_id ~= 'message_FT.json' then
    for i, item in ipairs(cache[media_id].programmes) do
      local media = {}
      media.id = item.id_diffusion
      media.title = item.titre
      media.genre = item.genre_simplifie
      media.creation_date = item.date
      media.thumbnail = url_base_images .. item.url_image_racine .. '.' .. item.extension_image
      media.url = url_base_videos .. item.url_video
      grl.callback(media, -1)
    end
    grl.callback()
  end
end
