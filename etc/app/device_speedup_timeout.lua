local string, table, os, tostring, ipairs, tonumber = string, table, os, tostring, ipairs, tonumber
local DEBUG = false

local mac_arg = arg[1]
local timeout_arg = arg[2]

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

local function notice()
  local datatypes = require "luci.cbi.datatypes"
  local util = require "luci.util"
  logger(mac_arg)
  local mac = util.format_mac(mac_arg)
  logger(mac)
  if not datatypes.macaddr(mac) then
    return false
  end
  local mq = require "hiwifi.mq"
  local service_name = "22"
  local service = service_name
  local url = "http://m.hiwifi.com/api/Router/routerPushAdd"
  local level = 2
  local timeout = 240
  local state = 1
  local rst, msg = mq.init_service(service, url, level, timeout, state)
  if not rst then
    return false
  end

  local device_mac, device_name = get_device_mac_name(mac)
  local notice_time = os.time()
  local timeout = tonumber(timeout_arg) or 0
  local finish_time = notice_time + timeout
  local msg = {service=service_name,
               content={device_mac=mac, 
                        device_name=device_name,
                        finish_time=finish_time
                        }
              }
  logger(msg)
  local msg_id = mq.add(msg)
  logger(msg_id)
  return msg_id
end

notice()
