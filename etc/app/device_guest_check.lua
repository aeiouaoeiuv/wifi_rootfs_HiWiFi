local string, table, os, tostring, ipairs, tonumber = string, table, os, tostring, ipairs, tonumber
local DEBUG = false

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

local function get_service_name()
  return "21"
end

local function register_guest_service()
  local mq = require "hiwifi.mq"
  local service_name = get_service_name()
  local service = service_name
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

local function add_msg(device_mac, device_name)
  local mq = require "hiwifi.mq"
  local connect_time = os.time()
  local msg = {service=get_service_name(), content={device_mac=device_mac, device_name=device_name, connect_time=connect_time}}
  logger(msg)
  local msg_id = mq.add(msg)
  logger(msg_id)
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

local function find_guest()
  logger('find_guest')
  local net = require "hiwifi.net"
  local dhcp_devicesResp = net.get_dhcp_client_list()
  logger(dhcp_devicesResp)
  if dhcp_devicesResp then
    local device_names = require "hiwifi.device_names"
    local device_names_list = device_names.get_all()
    logger(device_names_list)
    for _, net in ipairs(dhcp_devicesResp) do
      local device_mac = net['mac']
      local device_name = net['name']
      logger(device_mac)
      logger(device_names_list[device_mac])
      if not device_names_list[device_mac] then
        if add_if_new_guest(device_mac) then
          logger('new device mac '..device_mac.." name="..tostring(device_name))
          add_msg(device_mac, device_name)
          device_names.refresh(device_mac, device_name)
        end
      end
    end
  end
end

if register_guest_service() then
  find_guest()
end