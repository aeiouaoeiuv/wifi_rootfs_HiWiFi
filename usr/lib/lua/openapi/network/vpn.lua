local os, type = os, type
local utils = require("openapi.utils.utils")
local util = require("luci.util")

local vpn_base_dir = "/etc/vpn"

local uci = require "luci.model.uci"
local x = uci.cursor()

local DEBUG = true

--[[ 
config interface 'cn2ht'
        option ifname 'cn2ht'
        option proto 'l2tp'
        option peerdns '0'
        option defaultroute '0'
        option auto '0'
        option pppd_options 'refuse-eap'
        option username 'E075C438AFC60E8762F75D1B42526039'
        option password 'tlkdej'
        option server '61.154.237.195'
]]--

module("openapi.network.vpn", package.seeall)

local function check_data(data)
  if data.ifname == "" or data.ifname == nil or type(data.ifname) ~= "string" then
    return utils.ret_output("300001", "", "")
  end

  if data.ifname == "lan" or data.ifname == "wan" or data.ifname == "lo" then
  end
  return utils.ret_output("0", "", "")

end

function add(data)
  local check = check_data(data)
  if check.code ~= "0" then
    return check
  end

  local ret = x:set("network", data.ifname, "interface")
  if ret == false then
    return utils.ret_output("300002","", "vpn interface add failed")
  end
  x:set("network", data.ifname, "ifname", data.ifname)
  x:set("network", data.ifname, "defaultroute", "0")
  x:set("network", data.ifname, "pppd_options", "refuse-eap")
  x:commit("network")
  return utils.ret_output("0","", "vpn interface add success")
end

function del(data)
  local check = check_data(data)
  if check.code ~= "0" then
    return check
  end

  local ret = x:delete("network", data.ifname)
  x:commit("network")
  if ret == false then
    return utils.ret_output("300003","", "vpn interface del failed")
  else
    return utils.ret_output("0", "", "vpn interface del success")
  end
end

function set(data)
  local check = check_data(data)
  if check.code ~= "0" then
    return check
  end

  x:tset("network", data.ifname, data)
  x:commit("network")
end

function get(data)
  local check = check_data(data)
  if check.code ~= "0" then
    return check
  end
  local conf = x:get_all("network",data.ifname)
  return utils.ret_output("0", "vpn interface del success", conf)
end

function start(data)
  local check = check_data(data)
  if check.code ~= "0" then
    return check
  end
  cmd = "ifup $INTERFACE"
end

function stop(data)
  cmd = "ifdown $INTERFACE"
end

function status(data)
	cmd = 'ubus call network.interface.$INTERFACE status|grep "up"|grep "false" | wc -l'
end

function set_hostlist(data)
end

function set_iplist(data)
end
