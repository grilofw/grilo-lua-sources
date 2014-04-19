-- libquvi-scripts
-- Copyright (C) 2011-2013  quvi project
--
-- This file is part of libquvi-scripts <http://quvi.sourceforge.net/>.
--
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU Affero General Public
-- License as published by the Free Software Foundation, either
-- version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General
-- Public License along with this program.  If not, see
-- <http://www.gnu.org/licenses/>.
--

-- TODO:
-- - Add support for Radio programmes
-- - Add support for live streaming
-- - Offer the subtitles for download somehow

-- Obtained with grep -oP '(?<=service=")[^"]+(?=")' on config
local fmt_id_lookup = {
  high     = 'iplayer_streaming_h264_flv_high',
  standard = 'iplayer_streaming_h264_flv',
  low      = 'iplayer_streaming_h264_flv_lo',
  vlow     = 'iplayer_streaming_h264_flv_vlo'
  -- iplayer_streaming_n95_3g
  -- iplayer_streaming_n95_wifi
}

local BBC = {} -- Utility functions unique to this script

function BBC.can_parse_url(qargs)
  local U = require 'socket.url'
  local t = U.parse(qargs.input_url)
  if t and t.scheme and (t.scheme:lower():match('^https?$')
                         or t.scheme:lower():match('^http?$'))
       and t.host   and t.host:lower():match('www%.bbc%.co%.uk$')
       and t.path   and t.path:lower():match('/iplayer/')
  then
    return true
  else
    return false
  end
end

-- Iterates the available streams.
function BBC.iter_streams(config, U)
end

-- Identify the script.
function ident(qargs)
  return {
    can_parse_url = BBC.can_parse_url(qargs),
    domains = table.concat({'www.bbc.co.uk'}, ',')
  }
end

-- Parse video URL.
function parse(qargs)

    function needs_new_authString(params)
        if not params['authString'] then
            return false
        end
        local found = false
        for _,kind in pairs{'limelight', 'akamai', 'level3', 'sis', 'iplayertok'} do
            if kind == params['kind'] then
                found = true
                break
            end
        end
        if not found then return false end
        -- We don't need to check for the mode, we already know it's what we want
        return true
    end

    function create_uri_for_limelight_level3_iplayertok(params)
        params.uri = params.tcurl .. '/' .. params.playpath
    end

    function process_akamai(params)
        params.playpath = params.identifier
        params.application = params.application or 'ondemand'
        params.application = params.application .. '?_fcs_vhost=' .. params.server .. '&undefined'
        params.uri = 'rtmp://' .. params.server .. ':80/' .. params.application
        if not params.authString:find("&aifp=") then
            params.authString = params.authString .. '&aifp=v001'
        end
        if not params.authString:find("&slist=") then
            params.identifier = params.identifier:gsub('^mp[34]:', '')
            params.authString = params.authString .. '&slist=' .. params.identifier
        end
        params.playpath = params.playpath .. '?' .. params.authString
        params.uri = params.uri .. '&' .. params.authString
        params.application = params.application .. '&' .. params.authString
        params.tcurl = 'rtmp://' .. params.server .. ':80/' .. params.application
    end

    function process_limelight_level3(params)
        params.application = params.application .. '?' .. params.authString
        params.tcurl = 'rtmp://' .. params.server .. ':1935/' .. params.application
        params.playpath = params.identifier
        create_uri_for_limelight_level3_iplayertok(params)
    end

    function process_iplayertok(params)
        params.identifier = params.identifier .. '?' .. params.authString
        params.playpath = params.identifier:gsub('^mp[34]:', '')
        params.tcurl = 'rtmp://' .. params.server .. ':1935/' .. params.application
        create_uri_for_limelight_level3_iplayertok(params)
    end

    local _,_,s = qargs.input_url:find('episode/(.-)/')
    local episode_id = s or error('no match: episode id')
    qargs.id = episode_id

    local playlist_uri =
        'http://www.bbc.co.uk/iplayer/playlist/' .. episode_id
    local playlist = quvi.http.fetch(playlist_uri, {fetch_type = 'playlist'}).data

    local pl_item_p,_,s = playlist:find('<item kind="programme".-identifier="(.-)"')
    if not s then
        pl_item_p,_,s = playlist:find('<item kind="radioProgramme".-identifier="(.-)"')
        -- TODO: Implement radio support
        if s then
            error('No support for radio yet')
        end
    end
    local media_id = s or error('no match: media id')

    local _,_,s = playlist:find('duration="(%d+)"', pl_item_p)
    qargs.duration_ms = tonumber(s) or 0

    local _,_,s = playlist:find('<title>(.-)</title>')
    qargs.title = s or error('no match: video title')

    local _,_,s = playlist:find('<link rel="holding" href="(.-)"')
    qargs.thumb_url = s or ""

    -- stolen from http://lua-users.org/wiki/MathLibraryTutorial
    math.randomseed(os.time()) math.random() math.random() math.random()
    local config_uri =
        'http://www.bbc.co.uk/mediaselector/4/mtis/stream/' ..
        media_id .. "?cb=" .. math.random(10000)

    -- Get the list of available formats
    local config = quvi.http.fetch(config_uri, {fetch_type = 'config'}).data

    -- Drop out early if we're not in the UK
    local _,_,s = config:find('id="notukerror"')
    if s then
        error("Not supported from non-UK locations")
    end

    available_formats = {}
    for fmt_id in config:gmatch("iplayer_streaming_[%w_]+") do
        available_formats[#(available_formats) + 1] = fmt_id
    end
    if #(available_formats) == 0 then error('no formats available') end

    -- Iterate over <media/>s
    r = {}
    local S = require 'quvi/stream'
    for section in config:gmatch('<media .-</media>') do
        -- Initialise with the default values from the media
        local mparams = {}
        for _,mparam in pairs{'kind', 'service', 'type', 'height', 'width', 'bitrate'} do
            _,_,mparams[mparam] = section:find(mparam .. '="(.-)"')
            -- print ("MEDIA: mparams[" .. mparam .. "] = " .. mparams[mparam])
        end

        -- Skip subtitles for now
        if mparams.service == 'captions' then
            section = ""
        end

        for connection in section:gmatch('<connection .-/>') do
            local params, complete_uri = {}, ''

            for _,param in pairs{'supplier', 'server', 'application', 'identifier', 'authString', 'kind', 'href', 'protocol'} do
                _,_,params[param] = connection:find(param .. '="(.-)"')
                -- print ("CONNECTION: params[" .. param .. "] = " .. (params[param] or "(null)"))
            end

            -- Get authstring from more specific mediaselector if
            -- this mode is specified - fails sometimes otherwise
            if needs_new_authString(params) then
                local xml_uri =
                    'http://www.bbc.co.uk/mediaselector/4/mtis/stream/' ..
                    media_id .. '/' .. mparams['service'] .. '/' .. params['kind'] ..
                    "?cb=" .. math.random(10000)
                local xml = quvi.http.fetch(xml_uri, {fetch_type = 'config'}).data
                local _,_,new_authString = xml:find('authString="(.-)"')
                if new_authString then
                    params['authString'] = new_authString:gsub('&amp;', '&')
                end
            else
                -- Unescape the authString
                if params['authString'] then
                    params['authString'] = params['authString']:gsub('&amp;', '&')
                end
            end

            -- in 'application', mp has a value containing one or more entries separated by strings.
            -- We only keep the first entry.
            if params.application then
                params.application = params.application:gsub("&mp=([^,&]+),?.-&", "&mp=%1&")
            end

            if params.supplier == 'akamai' then
                process_akamai(params)
            end

            if (params.supplier == 'limelight' or params.supplier == 'level3') then
                process_limelight_level3(params)
            end

            if (params.protocol == 'http') then
                complete_uri = params.href
            end
            if (params.protocol == 'rtmp') then
                params.uri = params.uri or error('Could not create RTMP URL')

                complete_uri = params.uri
                    .. ' app=' .. params.application
                    .. ' playpath=' .. params.playpath
                    .. ' swfUrl=http://www.bbc.co.uk/emp/releases/iplayer/revisions/617463_618125_4/617463_618125_4_emp.swf swfVfy=1'
                    .. ' tcUrl=' .. params.tcurl
                    .. ' pageurl=' .. qargs.input_url
            end

            if complete_uri then
                local s = S.stream_new(complete_uri)
                s.container = mparams.type
                s.video.width = mparams.width
                s.video.height = mparams.height
                s.video.bitrate_kbit_s = mparams.bitrate
                s.id = mparams.service .. '_' .. params.kind
                table.insert(r, s)
            end
        end
    end

    if #r == 0 then error("Couldn't parse the config") end

    if #r >1 then
        BBC.ch_best (S, r)
    end

    qargs.streams = r

    return qargs
end

function BBC.ch_best(S, t, l)
  local r = t[1]
  r.flags.best = true
  for _,v in pairs(t) do
    if BBC.is_best_stream(v, r) then
      r = S.swap_best(r, v)
    end
  end
end

function BBC.is_best_stream(v1, v2)
  return v1.video.height > v2.video.height
           or (v1.video.height == v2.video.height
                 and v1.video.bitrate_kbit_s > v2.video.bitrate_kbit_s)
end

-- vim: set ts=2 sw=2 tw=72 expandtab:
