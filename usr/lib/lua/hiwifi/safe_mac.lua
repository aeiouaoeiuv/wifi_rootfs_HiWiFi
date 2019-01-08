-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local pairs, string, table = pairs, string, table
local sets = require "hiwifi.collection.sets"
local fs = require "nixio.fs"

module "hiwifi.safe_mac"

local SAFE_MAC_FILE = "/etc/app/safe_macs"

--- Gets all safe MAC addresses in a set.
--@return a set containing all safe MAC addresses.
function get_all()
  local file_content = fs.readfile(SAFE_MAC_FILE)
  local contant = {}
  if file_content ~= nil then
    for k in string.gmatch(file_content, "[^\n]+") do
      sets.add(contant, k)
    end
  end
  return contant
end

--- Saves safe MAC list into file.
--@param set the safe MAC list to be saved
local function save(set)
  fs.mkdirr(fs.dirname(SAFE_MAC_FILE))
  local list = sets.to_list(set)
  fs.writefile(SAFE_MAC_FILE, table.concat(list, "\n"))
end

--- Adds the specified MAC address into safe MAC list.
--@param mac the specified MAC address
function add(mac)
  local all = get_all()
  sets.add(all, mac)
  save(all)
end

--- Removes the specified MAC address from safe MAC list.
--@param mac the specified MAC address
function del(mac)
  local all = get_all()
  sets.remove(all, mac)
  save(all)
end

--- Lists all safe MAC addresses.
--@return a list containing all safe MAC addresses.
function list()
  return sets.to_list(get_all())
end
