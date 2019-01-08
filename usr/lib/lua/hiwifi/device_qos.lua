-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Wang Chao <chao.wang@hiwifi.tw>

local pairs, string, table = pairs, string, table
local sets = require "hiwifi.collection.sets"
local fs = require "nixio.fs"

module "hiwifi.device_qos"

local function normalize_mac(mac)
  return string.upper(string.gsub(mac,"-",":"))
end

local device_qos_FILE = "/etc/app/device_qos"

--- Gets all device name addresses in a set.
--@return a set containing all device name addresses.
function get_all()
  local file_content = fs.readfile(device_qos_FILE)
  local contant = {}
  if file_content ~= nil then
    for k in string.gmatch(file_content, "[^\n]+") do
      sets.add(contant, k)
    end
  end
  local lines = sets.to_list(contant)
  local mac_hash = {}
  for _,l in pairs(lines) do
	local mac,down,up= l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)')
	-- 兼容原来没有 name 的形式
	local name = string.gsub (l, '^[^%s]+%s+[^%s]+%s+[^%s]+', "")
	name = string.gsub (name, ' ', "")
	--local mac,down,up,name= l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)*?')
	if mac then 
		mac = normalize_mac(mac)
		mac_hash[mac] = {}
		mac_hash[mac]['up'] = up
		mac_hash[mac]['down'] = down
		mac_hash[mac]['name'] = name
	end
  end
  return mac_hash
end

--- Saves device name list into file.
--@param set the device name list to be saved
local function save(set)
  fs.mkdirr(fs.dirname(device_qos_FILE))
  local list = sets.to_list(set)
  fs.writefile(device_qos_FILE, table.concat(list, "\n"))
end

--- Adds the specified MAC address into device name list.
--@param mac the specified MAC address
function add(mac)
  local all = get_all()
  sets.add(all, mac)
  save(all)
end

--- Removes the specified MAC address from device name list.
--@param mac the specified MAC address
function del(mac)
  local all = get_all()
  sets.remove(all, mac)
  save(all)
end

--- Lists all device name addresses.
--@return a list containing all device name addresses.
function list()
  return sets.to_list(get_all())
end
