--[[
 * Copyright (C) 2015 Grilo Project
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

ALJAZEERA_LIVE_URL = 'rtmp://aljazeeraflashlivefs.fplive.net:443/aljazeeraflashlive-live?videoId=883816736001&lineUpId=&pubId=665003303001&playerId=751182905001&affiliateId=/aljazeera_eng_med?videoId=883816736001&lineUpId=&pubId=665003303001&playerId=751182905001&affiliateId= live=true'
ALJAZEERA_LIVE_TITLE = 'Al Jazeera Live Stream'

---------------------------
-- Source initialization --
---------------------------

source = {
  id = "grl-aljazeera",
  name = "Al Jazeera",
  description = "Drawing on the legacy of the groundbreaking Al Jazeera Arabic channel, Al Jazeera English was launched on November 15, 2006 to more than 80 million households worldwide. The 24-hour news and current affairs channel is the first international English-language news channel to broadcast across the globe from the Middle East."
  supported_keys = { 'id', 'title', 'url' },
  supported_media = 'video',
  tags = { 'tv', 'net:internet', 'net:plaintext' },
  icon = 'resource:///org/gnome/grilo/plugins/aljazeera/grilo/aljazeera.png'
}

------------------
-- Source utils --
------------------

local function send_media(media)
   media.type = 'video'
   media.id = 'live'
   media.title = ALJAZEERA_LIVE_TITLE
   media.url = ALJAZEERA_LIVE_URL
   grl.callback(media, 0)
end

---------------------------------
-- Handlers of Grilo functions --
---------------------------------

function grl_source_browse(media_id)
  local skip = grl.get_options("skip")

  if skip > 0 or media_id then
     grl.callback()
     return
  end

  local media = {}
  send_media(media)
end

function grl_source_resolve(media_id)
   if not media_id or media_id ~='live' then
      grl.callback(media, 0)
   else
      send_media(media)
   end
end
