-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local os, pairs, string, table, tonumber,ipairs,tostring = os, pairs, string, table, tonumber,ipairs,tostring
local hcwifi = require "hcwifi"
local status = require "luci.tools.status"
local network = require "luci.model.network"
local util = require "luci.util"
local tw = require "tw"
local uci = require "luci.model.uci"
local s = require "luci.tools.status"

module "hiwifi.net"

local DEVICE_ID = "radio0.network1"
local WIFI_IFNAMES
local WIFI_IFNAMES2

local function normalize_mac(mac)
  return string.lower(string.gsub(mac,"-",":"))
end

function get_dhcp_client_list()
  local devicesResp = {}
  local mac
  local name
  for _, user in pairs(status:dhcp_leases()) do
  	mac = normalize_mac(user["macaddr"])
  	name = ((user["hostname"] == false) and "" or user["hostname"])
    table.insert(devicesResp, {
      ['ip'] = user["ipaddr"],
      ['mac'] = mac,
      ['name'] = name
    })
  end
  return devicesResp 
end

--- Gets WIFI info including SSID and whether it's turned on.
function get_wifi_device()
  local net = status.wifi_network(DEVICE_ID)
  return {
    ['ssid'] = net["ssid"],
    ['is_on'] = (net["up"]) and 1 or 0
  }
end

--- Turns WIFI on. Do nothing if is already turned on.
function turn_wifi_on()

  local current_status = get_wifi_device()
  if current_status['is_on'] == 1 then
    return -- Do nothing if wifi is already on.
  end

  --Copied from Wang Chao. Changed luci.sys.call() to os.execute().
    local netmd = network.init()
    local net = netmd:get_wifinet(DEVICE_ID)
    local dev
    if net~=nil then 
        dev = net:get_device()
    end
    if dev and net then
        dev:set("disabled", nil)
        net:set("disabled", "0")
        netmd:commit("wireless")
        if not get_wifi_bridge() then --桥接状态下 ifup wan 包含  wifi 命令
        	os.execute("env -i /sbin/wifi >/dev/null 2>/dev/null")
        else 
        	os.execute("env -i  /sbin/ifup wan >/dev/null 2>/dev/null")
        end
    end
end

--- Turns WIFI off. Do nothing if is already turned off.
function turn_wifi_off()
  local current_status = get_wifi_device()
  if current_status['is_on'] == 0 then
    return -- Do nothing if wifi is already off.
  end

  --Copied from Wang Chao. Changed luci.sys.call() to os.execute().
    local netmd = network.init()
    local net = netmd:get_wifinet(DEVICE_ID)
    local dev

    if net~=nil then 
        dev = net:get_device()
    end

    if dev and net then
        dev:set("disabled", nil)
        net:set("disabled", "1")
        netmd:commit("wireless")
        if not get_wifi_bridge() then --桥接状态下 ifup wan 包含  wifi 命令
        	os.execute("env -i /sbin/wifi >/dev/null 2>/dev/null")
        else 
        	os.execute("env -i  /sbin/ifup wan >/dev/null 2>/dev/null")
        end
    end
end

--- Fetches wireless clients on TP-Link devices.
local function do_tl()
  local x = status.wifi_network(DEVICE_ID)
  
  local device_list = {}
  for bssid, data in pairs(x['assoclist']) do
    table.insert(device_list, {
      ['mac'] = normalize_mac(mac),
      ['signal'] = (data.signal - data.noise) * 2
    })
  end
  return device_list
end

--- Fetches wireless clients on HIWIFI devices.
local function do_hiwifi()
-- 获取 wifi 的 ifname 
  WIFI_IFNAMES,WIFI_IFNAMES2 = get_wifi_ifnames()
  local IFNAME = WIFI_IFNAMES[1]
  local KEY_STALIST = "stalist"
  local dev_lins = hcwifi.get(IFNAME, KEY_STALIST)
  local device_list = {}
  for _, sta in pairs(dev_lins) do
    table.insert(device_list, {
      ['mac'] = normalize_mac(sta["macaddr"]),
      ['signal'] = sta["ccq"],
      ['rpt'] = sta["rpt"],
      ['type_wifi'] = "2.4G"
    })
  end
  -- AC
  if WIFI_IFNAMES2[1] then 
  	IFNAME = WIFI_IFNAMES2[1]
  	dev_lins = hcwifi.get(IFNAME, KEY_STALIST)
  	for _, sta in pairs(dev_lins) do
    table.insert(device_list, {
      ['mac'] = normalize_mac(sta["macaddr"]),
      ['signal'] = sta["ccq"],
      ['rpt'] = sta["rpt"],
      ['type_wifi'] = "5G"
    })
	end
  end
  return device_list
end

-- get ap list
function get_aplist()
  WIFI_IFNAMES = get_wifi_ifnames()
  local IFNAME = WIFI_IFNAMES[1]
  local KEY_STALIST = "aplist"
  local ap_lins = hcwifi.get(IFNAME, KEY_STALIST)
  return ap_lins
end

--- Fetches wireless clients.
function get_wifi_client_list()
  return (string.sub(tw.get_model(), 1, 2) == "TL") and do_tl() or do_hiwifi()
end


-- get wifi bridge client
function get_wifi_bridge_client()
	local netmd = network.init()
	local wifi_device = netmd:get_wifidevs();
	local wifi_client_id 
	local wifi_device_name
	local dev
	for _, dev in ipairs(wifi_device) do
		local net
		for i, net in ipairs(dev:get_wifinets()) do
			if net:active_mode()=='Master' then
				wifi_device_name = net:get_device():name()
			end
			if net:active_mode()=='Client' then
				wifi_client_id = net:id()
			end
		end
	end
	return wifi_device_name,wifi_client_id
end

-- get wifi bridge
function get_wifi_bridge()
	local ssid
	local encryption
	local key
	local channel
	local disabled
	local wifi_device_name,wifi_client_id = get_wifi_bridge_client()
	local netmd = network.init()
	local net = netmd:get_wifidev(wifi_device_name)
	if net and wifi_client_id then 
		local wifinet = net:get_wifinet(wifi_client_id)
		if wifinet == nil then
			return false
		else 
			disabled =  wifinet:get("disabled")
			if disabled == "1" then 
				return false
			else 
				ssid = wifinet:get("ssid")
				encryption = wifinet:get("encryption")
				key = wifinet:get("key")
				bssid = wifinet:get("bssid")
				channel = tostring(wifinet:channel())
				return ssid,encryption,key,channel,bssid
			end
		end
	else 
		return false
	end
end

-- get wifi bridge connect
-- @return 1 - 已链接
-- 		   0 - 未连接
function get_wifi_bridge_connect()
	 WIFI_IFNAMES = get_wifi_ifnames()
     local IFNAME = WIFI_IFNAMES[2]
     if not IFNAME then IFNAME = "" end
	 local KEY_STALIST = "status"
	 local status = hcwifi.get(IFNAME, KEY_STALIST)
	 return status
end

-- 获取已经保存的 wifi 列表
function get_wifi_bridge_saved()
--	local uci = require "luci.model.uci"
--	_uci_real  = uci.cursor()
	local cnt = 0
	local output = {}
	local wifi_device_name,wifi_client_id = get_wifi_bridge_client()
	local netmd = network.init()
	local net = netmd:get_wifidev(wifi_device_name)
	if net and wifi_client_id then 
		local wifinet = net:get_wifinet(wifi_client_id)
		if wifinet == nil then
			return output
		else 
			while true do
			 	ssid = wifinet:get("ssid"..cnt)
				if ssid then 
					encryption = wifinet:get("encryption"..cnt)
					key = wifinet:get("key"..cnt)
					bssid = wifinet:get("bssid"..cnt)
				 	--_uci_real:get()
				    table.insert(output, {
				      ['ssid'] = ssid,
				      ['encryption'] = encryption,
				      ['key'] = key,
				      ['bssid'] = bssid
				    })
				    
				    cnt = cnt+1
				else
					return output
				end
			 end
		end
	end
	return output
end

-- del wifi bridge
function del_wifi_bridge()
	local wifi_device_name,wifi_client_id = get_wifi_bridge_client()
	local netmd = network.init()
	local net = netmd:get_wifidev(wifi_device_name)
	
	if net then
		if wifi_client_id~=nil and wifi_client_id~="" then
			local wifinet = net:get_wifinet(wifi_client_id)
			wifinet:set("disabled","1")
			netmd:commit("wireless")
			netmd:save("wireless")
		end
	end
	return 0
end

--- del bridge history
function del_bridge_history()

	local wifi_device_name,wifi_client_id = get_wifi_bridge_client()
	local netmd = network.init()	
	--插入运算代码
	local net = netmd:get_wifidev(wifi_device_name)
	local wifinet = net:get_wifinet(wifi_client_id)
	local saved_list = get_wifi_bridge_saved()
	local cnt = 0
	
	for k,v in pairs(saved_list) do
		wifinet:set("ssid"..cnt,nil)
		wifinet:set("encryption"..cnt,nil)
		wifinet:set("bssid"..cnt,nil)
		wifinet:set("key"..cnt,nil)
		cnt = cnt + 1
	end
	
	netmd:commit("wireless")
	netmd:save("wireless")
	
	return 0
end

function set_wifi_bridge(ssid,encryption,key,channel,bssid)
	local wifi_device_name,wifi_client_id = get_wifi_bridge_client()
	local netmd = network.init()	
	--插入运算代码
	local net = netmd:get_wifidev(wifi_device_name)
	if net then
	
		-- 设置 wireless
		    WIFI_IFNAMES = get_wifi_ifnames()
            local IFNAME = WIFI_IFNAMES[2]
            if not IFNAME then IFNAME = "" end
			local wconf = {ssid=ssid,encryption=encryption,key=key,network="wan",bssid=bssid,ifname=IFNAME,mode="sta",id=wifi_client_id,disabled="0"}
			if wifi_client_id==nil or wifi_client_id=="" then
				local r = net:add_wifinet(wconf);
				if r then
					wifi_client_id = r:id()
				end
			else
				local wifinet = net:get_wifinet(wifi_client_id)
				wifinet:set("ssid",ssid)
				wifinet:set("encryption",encryption)
				wifinet:set("bssid",bssid)
				wifinet:set("key",key)
				wifinet:set("network","wan")
				wifinet:set("disabled","0")
			end
			
			net:set("channel",channel);
			
	-- 保存到已连接过的列表
			local wifinet = net:get_wifinet(wifi_client_id)
			local saved_list = get_wifi_bridge_saved()
			local have_save = false
			local cnt = 0
			for k,v in pairs(saved_list) do
				if v['bssid'] == bssid then
					wifinet:set("ssid"..cnt,ssid)
					wifinet:set("encryption"..cnt,encryption)
					wifinet:set("bssid"..cnt,bssid)
					wifinet:set("key"..cnt,key)
					have_save = true
				end
				cnt = cnt + 1
			end
			
			if not have_save then
				wifinet:set("ssid"..cnt,ssid)
				wifinet:set("encryption"..cnt,encryption)
				wifinet:set("bssid"..cnt,bssid)
				wifinet:set("key"..cnt,key)
			end
			
			netmd:commit("wireless")
			netmd:save("wireless")
			
		-- 设置 network
		
			-- 设置 ifname 为  wlan1 
			local iface = "wan"
			local net2 = netmd:get_network(iface)
			local def_ifname = net2:get("def_ifname")
			
			-- 设置 wan 口 mac
			local wan_mac = net2:get("macaddr")
			if wan_mac == nil or wan_mac == "" then 
				-- 获取
				local config_line = util.exec("ifconfig|grep "..s.global_wan_ifname())
				if config_line ~= nil and config_line ~="" then
					local tmp1, tmp2, tmp3, tmp4, tmp5 = config_line:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)')	
					wan_mac = tmp5
				end
			end
	        WIFI_IFNAMES = get_wifi_ifnames()
            local IFNAME = WIFI_IFNAMES[2]
            if not IFNAME then IFNAME = "" end
			net2 = netmd:del_network(iface)
			net2 = netmd:add_network(iface, {proto="dhcp",ifname=IFNAME,macaddr=wan_mac,def_ifname=def_ifname})
			netmd:commit("network")
			netmd:save("network")
	end
	return 0
end

-- 获取 wifi 的 ifname 
function get_wifi_ifnames()
	local wifi_ifnames={}
	local wifi_ifnames_2={}
	_uci_real  = uci.cursor()
	_uci_real:foreach("wireless", "wifi-iface",
	function(s)
		table.insert(wifi_ifnames, s["ifname"])
		table.insert(wifi_ifnames_2, s["ifname2"])
	end)
	return wifi_ifnames,wifi_ifnames_2
end

-- 执行扫描周围 wifi 环境 (此动作3秒后才能在 get_aplist 中获得结果)
function do_wifi_ctl_scan()
	WIFI_IFNAMES = get_wifi_ifnames()
	local IFNAME = WIFI_IFNAMES[1]
	local result = hcwifi.ctl(IFNAME, "scan")
	return result
end