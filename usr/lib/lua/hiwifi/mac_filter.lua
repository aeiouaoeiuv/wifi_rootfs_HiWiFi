-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local pairs, os, string, table, ipairs = pairs, os, string, table, ipairs
local hcwifi = require "hcwifi"
local sets = require "hiwifi.collection.sets"
local lock = require "hiwifi.lock"
local datatypes = require "luci.cbi.datatypes"
local netmd = require "luci.model.network".init()
local hiwifi_net = require "hiwifi.net"
local fs = require "nixio.fs"
local WIFI_IFNAMES
module "hiwifi.mac_filter"

local WIFI_NET_NAME = "radio0.network1"
local BLOCK_LIST_FILE = "/etc/app/block_list"

local function normalize_mac(mac)
  return string.lower(mac)
end

local function normalize_mac_set(mac_set)
  local normalized_set = {}
  for mac, _ in pairs(mac_set) do
    sets.add(normalized_set, normalize_mac(mac))
  end
  return normalized_set
end

--- Checks whether the given setting is valid.
--@param setting the given setting
--@return true if valid, false if invalid
local function is_valid_setting(setting)
  local mode = setting.mode
  if mode ~= "stop" and mode ~= "allow" and mode ~= "deny" then
    return false
  end
  for mac, _ in pairs(setting.macs) do
    if not datatypes.macaddr(mac) then
      return false
    end
  end
  return true
end

--- Loads the MAC filter setting.
--@return the current mode (disabled, black list, white list) and a set containing all MAC addresses.
function load_setting()
  WIFI_IFNAMES = hiwifi_net.get_wifi_ifnames()
  local IFNAME = WIFI_IFNAMES[1]
  local KEY_ACL = "acl"
  local KEY_ACLLIST = "acllist"
  local list = hcwifi.get(IFNAME, KEY_ACLLIST)
  local mac_list = {}
  for _, obj in pairs(list) do
    table.insert(mac_list, obj["macaddr"])
  end
  
  local mode = hcwifi.get(IFNAME, KEY_ACL)
  local macs = normalize_mac_set(sets.from_list(mac_list))
  return {
    mode = (mode == "open" and "stop" or mode),
    macs = macs
  }
end

--- Saves the MAC filter setting.
--@param setting the new setting to be saved
--@return true if succeed, otherwise false
function save_setting(setting)
  setting.macs = normalize_mac_set(setting.macs)
  if not is_valid_setting(setting) then
    return false
  end
  
  local WIFI_IFNAMES,WIFI_IFNAMES2 = hiwifi_net.get_wifi_ifnames()
  if WIFI_IFNAMES then
    for k, v in ipairs(WIFI_IFNAMES) do
      save_setting_by_ifname(WIFI_IFNAMES[k],setting)
    end
  end
  --AC
  if WIFI_IFNAMES2 then
    for k, v in ipairs(WIFI_IFNAMES2) do
      if WIFI_IFNAMES2[k] then 
      	save_setting_by_ifname(WIFI_IFNAMES2[k],setting)
      end
    end
  end
  return true
end

function save_setting_by_ifname(ifname,setting)
  lock.lock("wireless")
  -- Xinggu's new interface to reload MAC filter list.
  local mode_string = (setting.mode == "stop" and "open" or setting.mode)
  local mac_list = sets.to_list(setting.macs)
  local mac_list_string = table.concat(mac_list, " ")
  hcwifi.set(ifname,"acl", mode_string)
  hcwifi.set(ifname,"acllist", mac_list_string)
  hcwifi.ctl(ifname,"aclchk")
  
  -- Still need to save to uci, otherwise it will be lost after restart.
  local net = netmd:get_wifinet(WIFI_NET_NAME)
  if setting.mode == "stop" then
    net:set("macfilter", "")
  else
    net:set("macfilter", setting.mode)
  end
  -- It will fail when an empty table is passed in, it needs nil.
  net:set("maclist", #mac_list > 0 and mac_list or nil)
  netmd:commit("wireless")
  netmd:save("wireless")
  lock.unlock("wireless")
  return true
end

--- Denies a specified MAC address.
-- If filtering is disabled, black list mode will be enabled first.
--@param mac the specified MAC address
--@return true if succeed, otherwise false
function deny_mac(mac)
  mac = normalize_mac(mac)
  local setting = load_setting()
  if setting.mode == "stop" then
    setting.mode = "deny"
    setting.macs = {}
  end
  if setting.mode == "allow" then
    sets.remove(setting.macs, mac)
  else
    sets.add(setting.macs, mac)
  end
  block_add(mac)
  return save_setting(setting)
end

--- Denies a specified MAC address. OLNY FOR APP NOW
-- If filtering is disabled, black list mode will be enabled first.
--@param mac the specified MAC address
--@return true if succeed, otherwise false
function allow_mac(mac)
  mac = normalize_mac(mac)
  local setting = load_setting()
  if setting.mode == "allow" then
    sets.add(setting.macs, mac)
  elseif setting.mode == "deny" then
  	sets.remove(setting.macs, mac)
  end
  block_del(mac)
  return save_setting(setting)
end

--- Disables the mac filtering.
--@return true if succeed, otherwise false
function disable()
  return save_setting({
    mode = "stop",
    macs = {}
  })
end

--------------------------------------------------------
-- BOCK_LIST
--------------------------------------------------------

-- Gets all block device  by line.
function block_get_all()
  local setting = load_setting()
  if setting.mode == "allow" or setting.mode == "stop" then
    return {}
  else
    return setting.macs
  end
end

--- Saves block device  list into file.
--@param set the block device  list to be saved
local function block_save(set)
  fs.mkdirr(fs.dirname(BLOCK_LIST_FILE))
  local list = sets.to_list(set)
  fs.writefile(BLOCK_LIST_FILE, table.concat(list, "\n"))
end

--- Adds the  address into block device  list.
--@param mac the block device  address
function block_add(mac)
  local all = block_get_all()
  sets.add(all, mac)
  block_save(all)
end

--- Removes the block device  address from block device  list.
--@param mac the block device  address
function block_del(mac)
  local all = block_get_all()
  sets.remove(all, mac)
  block_save(all)
end

--- Lists all block device  addresses.
--@return a list containing all block device  addresses.
function block_list()
  return sets.to_list(block_get_all())
end