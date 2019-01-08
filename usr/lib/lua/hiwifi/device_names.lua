-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Wang Chao <chao.wang@hiwifi.tw>

local pairs, string, table, print = pairs, string, table, print
local sets = require "hiwifi.collection.sets"
local fs = require "nixio.fs"
local u = require "luci.util"

module "hiwifi.device_names"

local function normalize_mac(mac)
    return string.lower(string.gsub(mac,"-",":"))
end

local DEVICE_NAMES_FILE = "/etc/app/device_names"

--- Gets all device name addresses in a set.
--@return a set containing all device name addresses.
function get_all()
  local file_content = fs.readfile(DEVICE_NAMES_FILE)
  local contant = {}
  if file_content ~= nil then
    for k in string.gmatch(file_content, "[^\n]+") do
      sets.add(contant, k)
    end
  end
  local lines = sets.to_list(contant)
  
  local mac_hash = {}
  for _,l in pairs(lines) do
    local mac_1,name_1 = l:match('^([^%s]+)::([^\n]+)')
    if mac_1 then
      mac_1 = normalize_mac(mac_1)
      mac_hash[mac_1] = name_1
    end
  end
  return mac_hash
end

-- Gets all device name by line.
function get_all_line()
  local file_content = fs.readfile(DEVICE_NAMES_FILE)
  local contant = {}
  if file_content ~= nil then
    for k in string.gmatch(file_content, "[^\n]+") do
      local mac, name = k:match('^[^%s]+::[^\n]*')
      if mac then
        sets.add(contant, k)
      end
    end
  end
  return contant
end

--- Saves device name list into file.
--@param set the device name list to be saved
local function save(set)
  fs.mkdirr(fs.dirname(DEVICE_NAMES_FILE))
  local list = sets.to_list(set)
  fs.writefile(DEVICE_NAMES_FILE, table.concat(list, "\n"))
end

--- Adds the  address into device name list.
--@param mac the device name address
function add(mac_name)
  local all = get_all_line()
  if mac_name then
    sets.add(all, string.gsub(mac_name,"%c",""))
  end
  save(all)
end

--- Removes the device name address from device name list.
--@param mac the device name address
function del(mac)
  local all = get_all_line()
  sets.remove(all, mac)
  save(all)
end

--- Removes the device name address from device name list.
--@param mac the device name address
function del_line(mac)
  if mac == nil or mac == "" then 
    return false
  end
  mac = normalize_mac(mac)
  local file_content_save = ""
  local file_content = fs.readfile(DEVICE_NAMES_FILE)
  for k in string.gmatch(file_content, "[^\n]+") do
    local mac_1,name_1 = k:match('^([^%s]+)::([^\n]+)')
    if mac_1 then
      mac_1 = normalize_mac(mac_1)
    end
    if mac ~= mac_1 then 
      file_content_save = file_content_save..k.."\n"
    end
  end
  fs.mkdirr(fs.dirname(DEVICE_NAMES_FILE))
  fs.writefile(DEVICE_NAMES_FILE, file_content_save)
end

--- Lists all device name addresses.
--@return a list containing all device name addresses.
function list()
  return sets.to_list(get_all())
end

-- refresh device list (if exist reflash the device name, or add one)
-- @param force ,  if force is true will update the old one ,or will keep old name
function refresh(mac,name,force)
  if name == "" or name == nil or mac == "" or mac == nil then 
    return false
  end
  if force == nil then 
    force = false
  end
  have_name = false
  mac = normalize_mac(mac)
  if force then
    del_line(mac)
    add(mac.."::"..name)
  else 
    local device_name_all = get_all()
      table.foreach(device_name_all, function(mac_one, name_one)
        mac_one = normalize_mac(mac_one)
         if mac_one == mac then 
           have_name = true
         end
      end)
      if not have_name then 
        del_line(mac)
      add(mac.."::"..name)
      end
  end
  return true
end
