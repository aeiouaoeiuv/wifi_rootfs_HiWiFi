local string, table, os, tostring, ipairs, tonumber, pcall, pairs = string, table, os, tostring, ipairs, tonumber, pcall, pairs
local DEBUG = false

local function logger(data)
  if DEBUG == true then
    local util = require "luci.util"
    util.logger(data)
  end
end

local function register_backhome_service()
    local mq = require "hiwifi.mq"
    local service_name = "41"
    local service = service_name
    local url = "http://m.hiwifi.com/api/Router/routerPushAdd"
    local level = 4
    local timeout = 600
    local state = 1
    local rst, msg = mq.init_service(service, url, level, timeout, state)
    if not rst then
      return false
    end
    return true
end

local function is_doubt(mac)
  local dubt = nil
  local function is_guest()
    local device_guest = require "hiwifi.device_guest"
    dubt = device_guest.find(mac)
  end
  pcall(is_guest)
  if dubt then
    return 1
  else
    return 0
  end
end

local function his_device_list(days)
  local his_list = {}
  if days then
    local util = require "luci.util"
    local time
    for day=1, days do
      time = util.get_date_format(day - 1)
      local forse_offline = nil
      if day > 1 then
        forse_offline = true
      end
      local data = util.get_time_his_device_list(time, forse_offline)
      local data_simple = {}
      for k, v in ipairs(data) do
        local time_range = util.get_traffic_day_dev_range(v.mac, time, 300)
        local online_time = time_range[1][1]
        local offline_time = time_range[1][2]
        data_simple[#data_simple + 1] = {device_mac=v.mac,
                                         device_name=v.name,
                                         online_time=online_time,
                                         offline_time=offline_time,
                                         is_online=v.online,
                                         is_doubt=is_doubt(v.mac)
                                         }
      end
      his_list[#his_list + 1] = data_simple
    end
  end
  return his_list
end

---  清空可疑设备
local function clear_device_guest()
  local device_guest = require "hiwifi.device_guest"
  local all = device_guest.get_all()
  logger(all)
  if all then
    for k, v in pairs(all) do
      device_guest.del(k)
    end
  end
end

--- 回家提醒，最多检测2天
local function notice_backhome(device_mac, device_name, connect_time)
  if register_backhome_service() then
    local util = require "luci.util"
    local mq = require "hiwifi.mq"
    local days = 2
    local msg = {service="41", content={device_list=his_device_list(days)}
                }
    logger(msg)
    local msg_id = mq.add(msg)
    logger(msg_id)
    
    -- TODO 临时处理
    clear_device_guest()
  end
end

notice_backhome()
