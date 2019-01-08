local string, table, os, tostring, ipairs, tonumber = string, table, os, tostring, ipairs, tonumber
local DEBUG = false

-- (assoc)
local action = arg[1]
local vap = arg[2]
local mac_arg = arg[3]
local rssi = arg[4]

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

local function is_block(mac)
  local fs = require "nixio.fs"
  local block_list = "/etc/app/block_list"
  local block_list_content = fs.readfile(block_list)
  if block_list_content and string.find(block_list_content, tostring(mac)) then
    return true
  end
  return false
end

local function refresh_dhcp()
  logger('refresh_dhcp')
  local net = require "hiwifi.net"
  local dhcp_devicesResp = net.get_dhcp_client_list()
  logger(dhcp_devicesResp)
  if dhcp_devicesResp then
    local device_names = require "hiwifi.device_names"
    for _, net in ipairs(dhcp_devicesResp) do 
      if net['name'] then 
        local result_devicename = device_names.refresh(net['mac'],net['name'])
      end
    end
  end
end

local function add_if_new_guest(mac)
   local device_guest = require "hiwifi.device_guest"
   if not device_guest.find(mac) then
     device_guest.add(mac)
     logger('add guest '..tostring(mac))
     return true
   end
   return false
end

-- Online
if action == 'assoc' then
  logger("assoc")
  local datatypes = require "luci.cbi.datatypes"
  local util = require "luci.util"
  local mac = util.format_mac(mac_arg)
  logger(mac)
  if datatypes.macaddr(mac) then
    local mq = require "hiwifi.mq"
    local service_name = "21"
    local service = service_name
    local url = "http://m.hiwifi.com/api/Router/routerPushAdd"
    local level = 2
    local timeout = 600
    local state = 1
    local rst, msg = mq.init_service(service, url, level, timeout, state)
    if not rst then
      return
    end

    -- This is the right code
    if not is_block(mac) then
      logger(tostring(mac)..' not block')
      local device_mac, device_name = get_device_mac_name(mac)
      if not device_mac then
        logger(tostring(mac)..' not found in device_names')
        if add_if_new_guest(mac) then
          logger(tostring(mac)..' add to device guest')
          --- Wait sys update dhcp
          os.execute("sleep 3")
          refresh_dhcp()
          device_mac, device_name = get_device_mac_name(mac)
          local connect_time = os.time()
          local msg = {service=service_name, content={device_mac=mac, device_name=device_name, connect_time=connect_time}}
          local msg_id = mq.add(msg)
        else
          logger(tostring(mac)..' found in device guest')
        end
      else
        logger(tostring(mac)..' found in device_names')
      end
    else
      logger(tostring(mac)..' is block')
    end
    
  end
end
