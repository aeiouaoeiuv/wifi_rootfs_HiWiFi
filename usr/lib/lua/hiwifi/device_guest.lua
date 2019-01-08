-- Copyright (c) 2014 Elite Co., Ltd.
-- Author: Chaogang Liu <chaogang.liu@hiwifi.tw>

local pairs, string, table, tonumber = pairs, string, table, tonumber
local sets = require "hiwifi.collection.sets"
local fs = require "nixio.fs"

module "hiwifi.device_guest"

local function normalize_mac(mac)
  return string.lower(string.gsub(mac,"-",":"))
end

local device_guest_file = "/etc/app/device_guest"

--- Gets all device name addresses in a set.
--@return a set containing all device name addresses.
function get_all()
  local file_content = fs.readfile(device_guest_file)
  local contant = {}
  if file_content ~= nil then
    for k in string.gmatch(file_content, "[^\n]+") do
      sets.add(contant, k)
    end
  end
  local lines = sets.to_list(contant)
  local mac_hash = {}
  for _,l in pairs(lines) do
	local mac= l:match('^([^%s]+)')
	if mac then 
		mac = normalize_mac(mac)
		mac_hash[mac] = {}
	end
  end
  return mac_hash
end

--- Saves device name list into file.
--@param set the device name list to be saved
local function save(set)
  fs.mkdirr(fs.dirname(device_guest_file))
  local list = {}
  for k, v in pairs(set) do
    table.insert(list, k)
  end
  fs.writefile(device_guest_file, table.concat(list, "\n"))
end

--- Adds the specified MAC address into device name list.
--@param mac the specified MAC address
function add(mac)
  local all = get_all()
  local nor_mac = normalize_mac(mac)
  if all[nor_mac] then
    all[nor_mac] = nil
  end
  all[nor_mac] = {}
  save(all)
end

--- Removes the specified MAC address from device name list.
--@param mac the specified MAC address
function del(mac)
  local all = get_all()
  local nor_mac = normalize_mac(mac)
  if all[nor_mac] then
    all[nor_mac] = nil
  end
  save(all)
end

function find(mac)
  local all = get_all()
  local nor_mac = normalize_mac(mac)
  if all[nor_mac] then
    return all[nor_mac]
  end
  return false
end
