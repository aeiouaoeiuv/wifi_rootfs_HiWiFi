local mq = require "hiwifi.mq"

local string, table, os, tostring, ipairs, tonumber, type = string, table, os, tostring, ipairs, tonumber, type
local DEBUG = true

local function logger(data)
  if DEBUG == true then
    local util = require "luci.util"
    util.logger(data)
  end
end

local function get_device_mac_name(mac)
  local device_names = require "hiwifi.device_names"
  local device_name_all = device_names.get_all()
  local device_mac = nil
  local device_name = device_name_all[mac]
  if device_name then
    device_mac = mac
  end
  return device_mac, device_name
end

local function service_name()
  return "23"
end

local function register_service()
  local service = service_name()
  local url = "http://m.hiwifi.com/api/Router/routerPushAdd"
  local level = 2
  local timeout = 600
  local state = 1
  local rst, msg = mq.init_service(service, url, level, timeout, state)
  if not rst then
    return false
  end
  return true
end

local function get_channel(deviceReq)
  logger("get_channel")
  local netmd = require "luci.model.network".init()
  local net = netmd:get_wifinet(deviceReq)
  local channelResp
  if net then 
    if net:active_mode()=='Master' then
      channelResp = tostring(net:channel())
      logger("tostring(net:channel())")
      logger(channelResp)
      if(channelResp == "0") then
        local hcwifi = require "hcwifi" 
        local IFNAME = net:ifname()--"wlan0" 
        local KEY_CH = "ch" 
        local channel_autorealResp = hcwifi.get(IFNAME, KEY_CH) 
        channelResp = channel_autorealResp
        logger("hcwifi.get(IFNAME, KEY_CH) ")
        logger(channelResp)
      end
      -- 获取不到 chnnal 补丁
      if channelResp == nil or channelResp == "" then
        local hiwifi_net = require "hiwifi.net"
        local hcwifi = require "hcwifi"
        local WIFI_IFNAMES = hiwifi_net.get_wifi_ifnames()
        local IFNAME = WIFI_IFNAMES[1]
        local KEY_CH = "ch" 
        channelResp = hcwifi.get(IFNAME, KEY_CH)
        logger("hcwifi.get(IFNAME, KEY_CH) nil")
        logger(channelResp)
      end
    end
  end
  logger(channelResp)
  return channelResp
end

local function get_channel_rank()
  local hiwifi_net = require "hiwifi.net"
  local net = require "hiwifi.net"
  local util = require "luci.util"
  local rankResp = {}
  local result = hiwifi_net.do_wifi_ctl_scan()
  
  local sleeptimes = 0
  while sleeptimes < 10 do
    --aplist
    local aplist = net.get_aplist()
    if aplist ~= nil and table.getn(aplist) > 0 then
      local i,v
      for i,v in ipairs(aplist) do
        aplist[i]["ssid"] = util.fliter_unsafe(aplist[i]["ssid"])
      end
      --rank
      rankResp = util.get_channel_rank(aplist)
      if rankResp ~= nil and ((0 <= rankResp[1]) and (rankResp[1] <= 1)) then
        break
      end
    end
    os.execute("sleep 1")
    sleeptimes = sleeptimes + 1
  end
  return rankResp
end

local function notice()
  if not register_service() then
    return false
  end

  local recommend_channel
  local channel = get_channel("radio0.network1")
  logger(channel)
  local channel_rank = get_channel_rank()
  logger("channel_rank")
  logger(channel_rank)
  local channel_index = tonumber(channel)
  if not channel_index then
    logger("invalid channel")
    return false
  end
  if type(channel_rank) == "table" then
    local rank = channel_rank[channel_index]
    if not rank then
      logger("invalid rank "..tostring(rank))
      return false
    end
    if tonumber(rank) <= 0.5 then
      logger("channel_rank[channel_index]")
      logger(channel_rank[channel_index])
      return true
    else
      local recommend_channel_rank = 1
      for k, v in ipairs(channel_rank) do
        if k < 12 then
          if recommend_channel_rank > v then
             recommend_channel_rank = v
             recommend_channel = k
          end
        end
      end
    end
  end
  logger("recommend_channel")
  logger(recommend_channel)
  if recommend_channel then
    local notice_time = os.time()
    local msg = {service = service_name(),
                 content = {channel_current = tonumber(channel),
                          channel_recommend = tonumber(recommend_channel)}
                }
    logger(msg)
    local msg_id = mq.add(msg)
    logger(msg_id)
    return msg_id
  end
  return false
end

notice()
