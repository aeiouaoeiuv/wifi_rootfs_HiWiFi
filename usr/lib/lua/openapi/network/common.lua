--[[
	Info	网络设置 api
	Author	longfei.qiao <longfei.qiao@hiwifi.tw>
	Copyright	2014
]]--

module("openapi.network.common", package.seeall)

---------------------------------------------------------------------------------------
--	全局函数 变量
---------------------------------------------------------------------------------------

-- 获取 lan 口是否链接
local DEVICE_NAMES_FILE = "/etc/app/device_names"
local DEVICE_QOS_FILE = "/etc/app/device_qos"
local fs = require "nixio.fs"
local socket_http = require "socket.http"
local socket_https = require "ssl.https"
local json = require("hiwifi.json")
local util = require("luci.util")
local dns_file_path = "/tmp/resolv.conf.auto"
local l2tp_flag = "vpn"
local hiwifi_net = require "hiwifi.net"
local WIFI_IFNAMES
local s = require "luci.tools.status"

local function normalize_mac(mac)
	return string.lower(string.gsub(mac,"-",":"))
end

-- 是否是桥接
function is_bridge()
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	local wan_if = _uci_real:get("network", "wan", "ifname")
	WIFI_IFNAMES = hiwifi_net.get_wifi_ifnames()
	local IFNAME = WIFI_IFNAMES[2]
	if wan_if == IFNAME then
		return true
	end
	return false
end

-- 设置 wan 口的链接类型 和 状态
-- 
-- 参数
-- ifname 			小设备是 eht0,大设备的 eth1
-- typeReq
-- mobile_typeReq
-- mobile_dev_usbReq
-- pppoe_nameReq
-- pppoe_passwdReq
-- static_ipReq
-- static_gwReq
-- static_dnsReq
-- static_dns2Req
-- static_maskReq

--function set_wan_contact_info(ifname,typeReq,mobile_typeReq,mobile_dev_usbReq,pppoe_nameReq,pppoe_passwdReq,static_ipReq,static_gwReq,static_dnsReq,static_dns2Req,static_maskReq)
--	
--end

--pppoe配置
function proc_pppoe(pppoe_name,pppoe_passwd,dns,dns2,peerdns)
	local netmd = require "luci.model.network".init()
	local iface = "wan"
	local code = 0
	local def_ifname
	
	local ifname_tmp = s.global_wan_ifname()
	
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	mac_reset = _uci_real:get("network", "wan", "macaddr")
	def_ifname = _uci_real:get("network", "wan", "def_ifname")
	
	local net = netmd:del_network(iface)
	
	-- 自定义 dns
	local dns_rs
	if peerdns == 0 or peerdns == "0" then
		if dns ~= nil and dns ~= "" and dns2~=nil and dns2~="" then
			dns_rs = {dns,dns2}
		elseif dns ~= nil and dns ~= "" then 
			dns_rs = dns
		end
	end
	
	--pppoe_name utf8 to gb2312 -- 暂时不支持
	if luci.util.isExistModule("iconv") then 
		-- DO utf8 -> gb2312
		local iconv = require "iconv"
		local cd = iconv.new('gb2312','utf8')
		--cd = iconv.new("utf-8", "GB2312")
  		--cd = iconv.open(to, from)
  		local pppoe_name_tmp , err = cd:iconv(pppoe_name)
  		if not err then 
  			pppoe_name = pppoe_name_tmp
  		end
	end
	
	net = netmd:add_network(iface, {proto="pppoe",ifname=ifname_tmp,username=pppoe_name,password=pppoe_passwd,dns=dns_rs,peerdns=peerdns,macaddr=mac_reset,def_ifname=def_ifname})
	if net then
		luci.sys.call("env -i /bin/cp /etc/ppp/options.default /etc/ppp/options >/dev/null 2>/dev/null")
		--luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
		netmd:commit("network")
		netmd:save("network")
	else 
		code = 1000
	end
	return code
end

--dhcp 和 静态 配置
function proc_ip(ip_type,ip,mask,gw,dns,dns2,peerdns)
	local netmd = require "luci.model.network".init()
	local iface = "wan"
	local ifname
	local def_ifname

	ifname = s.global_wan_ifname()
	
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	mac_reset = _uci_real:get("network", "wan", "macaddr")
	def_ifname = _uci_real:get("network", "wan", "def_ifname")
	
	local net = netmd:del_network(iface)
	local code = 0
	
	--703N设备需要删除Lan口的ifname:start
--	local lan = netmd:get_network("lan")				
--	if lan and lan:get_option_value("ifname")~="" then			
--	    ifname = lan:get_option_value("ifname")
--		lan:del_interface(lan:get_option_value("ifname"))
--	end
		
	if ip_type == "dhcp" then
	
		-- 自定义 dns
		local dns_rs
		if peerdns == 0 or peerdns == "0" then
			if dns ~= nil and dns ~= "" and dns2~=nil and dns2~="" then
				dns_rs = {dns,dns2}
			elseif dns ~= nil and dns ~= "" then 
				dns_rs = dns
			end
		end
	
		net = netmd:add_network(iface, {proto="dhcp",ifname=ifname,dns=dns_rs,peerdns=peerdns,macaddr=mac_reset,def_ifname=def_ifname})
		
		if net then	
			-- move to down
		else 
			code = 1000
		end
	elseif ip_type == "static" then
		local dns_rs
		if dns2==nil or dns2=="" then
			dns_rs = dns
		else
			dns_rs = {dns,dns2}
		end
		net = netmd:add_network(iface, {proto="static",ipaddr=ip,netmask=mask,gateway=gw,dns=dns_rs,ifname=ifname,macaddr=mac_reset,def_ifname=def_ifname});
		if net then
			-- move to down
		else 
			code = 1000
		end
	end
	
	if code == 0 then 
		luci.sys.call("env -i /bin/cp /etc/ppp/options.default /etc/ppp/options >/dev/null 2>/dev/null")
		--luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
		netmd:commit("network")
		netmd:save("network")
		--在 set_wan_connect 的时候有过一次重启 ifup wan，这里不用
		--luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
	end
	
	return code
end

--设置3G移动设备
--return code
function proc_mobile(mobile_type,mobile_dev_usb)
	local code = 0
	if mobile_type == nil or mobile_type == "" or mobile_dev_usb == nil or mobile_dev_usb == "" then
		code = 514
		return code
	end
	
	local netmd = require "luci.model.network".init()
	local iface = "wan"
	local ifname_tmp

	ifname_tmp = s.global_wan_ifname()
	
	local lan = netmd:get_network("lan")				
	if lan and lan:get_option_value("ifname")~="" then					
		if lan:get_option_value("ifname")~=ifname_tmp then
			lan:del_interface(lan:get_option_value("ifname"))	
			lan:add_interface(ifname_tmp)
		end
	else
		lan:add_interface(ifname_tmp)
	end
	
	--联通3G上网卡
	if mobile_type == "10010" then
		local net = netmd:del_network(iface)
		net = netmd:add_network(iface, {
			proto="3g",
			ifname="ppp0",
			device=mobile_dev_usb,  
			service="umts"
			});

		if net then

			luci.sys.call("env -i /bin/cp /etc/ppp/options.3g /etc/ppp/options >/dev/null 2>/dev/null")
			luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
			netmd:commit("network")
			netmd:save("network")								
			luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)

		else 
			code = 1000
		end
		
	--电信3G上网卡
	elseif mobile_type == "10000" then
		local net = netmd:del_network(iface)
		net = netmd:add_network(iface, {
			ifname="ppp0",
			device=mobile_dev_usb,
			service="evdo",
			proto="3g",
			username="ctnet@mycdma.cn",
			password="vnet.mobi"
			});
			
		if net then

			luci.sys.call("env -i /bin/cp /etc/ppp/options.3g /etc/ppp/options >/dev/null 2>/dev/null")
			luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
			netmd:commit("network")
			netmd:save("network")
			luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
		else 
			code = 1000
		end
		
	--中国移动3G上网卡
	elseif mobile_type == "10086" then
		local net = netmd:del_network(iface)
		net = netmd:add_network(iface, {
			ifname="ppp0",
			device=mobile_dev_usb,
			service="umts",
			proto="3g",
			apn="cmnet",
			username="net",
			password="net"
			});
			
		if net then

			luci.sys.call("env -i /bin/cp /etc/ppp/options.3g /etc/ppp/options >/dev/null 2>/dev/null")
			luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
			netmd:commit("network")
			netmd:save("network")
			luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)

		else 
			code = 1000
		end
	end
	return code
end

---------------------------------------------------------------------------------------
--	2.01 lan 获取 局域网状态 
---------------------------------------------------------------------------------------

function get_lan_info()
	-- 参数
	
	-- 返回值
	local ipv4Resp = {}
	local ipv6Resp = {}
	local statusResp
	local gate_wayResp
	local dns_ipResp = {}
	local macResp
	local uptimeResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	local resultResp
	
	--插入运算代码
	local interface = "lan"
	resultResp,ipv4Resp,ipv6Resp,statusResp,gate_wayResp,dns_ipResp,macResp,uptimeResp,mtuResp = luci.util.get_lan_wan_info(interface)
	
	if resultResp ~= false then
	else 
		codeResp = 511
	end
	
	-- 获取2个口连接状态 		
	arr_out_put["is_lan_link"] = {}
	arr_out_put["is_lan_link"]['lan_1'] = luci.util.is_lan_link(1)
	arr_out_put["is_lan_link"]['lan_2'] = luci.util.is_lan_link(2)
	arr_out_put["is_lan_link"]['lan_3'] = luci.util.is_lan_link(3)
	arr_out_put["is_lan_link"]['lan_4'] = luci.util.is_lan_link(4)
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["ipv4"] = ipv4Resp
		arr_out_put["ipv6"] = ipv6Resp
		arr_out_put["status"] = statusResp
		arr_out_put["gate_way"] = gate_wayResp
		arr_out_put["dns_ip"] = dns_ipResp
		arr_out_put["mac"] = macResp
		arr_out_put["uptime"] = uptimeResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	2.02 lan 设置局域网 ip
---------------------------------------------------------------------------------------

function set_lan_ip(data)
	
	-- 参数

	local ipReq = data.ip
	--local maskReq = data("mask")
	
	-- http://trac/hc/ticket/15 写死为 255.255.255.0
	maskReq = "255.255.255.0"
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	-- 检查 ip 和子网掩码
	local datatypes = require "luci.cbi.datatypes"	
	
	if not datatypes.ipaddr(ipReq) then
		codeResp = 512
	end
	
	if not datatypes.ipaddr(maskReq) then
		codeResp = 513
	end
	
	local bit = require "bit"
	local interface= "wan"
	_,wanipv4 = luci.util.get_lan_wan_info(interface)

	local iptool = luci.ip
	local lanipnl = iptool.iptonl(ipReq)
	local lanmasknl = iptool.iptonl(maskReq)
	
	if (wanipv4[1]) then 
		if not (bit.band(iptool.iptonl(ipReq),iptool.iptonl(maskReq)) ~= bit.band(iptool.iptonl(wanipv4[1]['ip']),iptool.iptonl(maskReq)) and bit.band(iptool.iptonl(ipReq),iptool.iptonl(wanipv4[1]['mask'])) ~= bit.band(iptool.iptonl(wanipv4[1]['ip']),iptool.iptonl(wanipv4[1]['mask']))) then 
			-- (WANIP & WANMASK != LANIP & WANMASK) && (WANIP & LANMASK != LANIP & LANMASK)
			codeResp = 533
		end
	end
	if not ((lanipnl >= iptool.iptonl("1.0.0.0") and lanipnl <= iptool.iptonl("126.255.255.255")) or (lanipnl >= iptool.iptonl("128.0.0.0") and lanipnl <= iptool.iptonl("223.255.255.255"))) then 
		codeResp = 540
	elseif lanipnl >= iptool.iptonl("172.31.0.0") and lanipnl <= iptool.iptonl("172.31.255.255") then 
		codeResp = 541
	elseif not (bit.band(lanipnl,iptool.ipnot(maskReq)) ~= 0 and bit.band(lanipnl,iptool.ipnot(maskReq)) ~= iptool.ipnot(maskReq)) then 
		-- ip & (~mask)不能为0，且ip & (~mask)不能为(~mask)
		codeResp = 535
	end
	
	-- 开始修改
	if (codeResp == 0) then
		local netmd = require "luci.model.network".init()
		local iface = "lan"
		local net = netmd:get_network(iface)	
	
		net:set("ipaddr",ipReq)
		net:set("netmask",maskReq)			
		netmd:commit("network")
		netmd:save("network")
	end 
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	-- 重启
	if (codeResp == 0) then
		os.execute("hwf-at 3 env -i /sbin/reboot & >/dev/null 2>/dev/null")
	end

	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.11 wan获取 互联网状态
---------------------------------------------------------------------------------------

function get_wan_info()
	
	-- 参数

	-- 返回值
	local typeResp
	local mobile_typeResp
	local mobile_dev_usbResp
	local pppoe_nameResp
	local pppoe_passwdResp
	local static_ipResp
	local static_gwResp
	local static_dnsResp
	local static_dns2Resp
	local static_maskResp
	local ipv4Resp
	local ipv6Resp
	local statusResp
	local gate_wayResp
	local dns_ipResp
	local special_dialResp
	local macResp
	local uptimeResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	-- 参数

	-- 返回值
	local ipv4Resp = {}
	local ipv6Resp = {}
	local statusResp
	local gate_wayResp
	local dns_ipResp = {}
	local macResp
	local uptimeResp
	local is_eth_linkResp
	local is_internet_linkResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码

	--插入运算代码
	local interface = "wan"
	resultResp,ipv4Resp,ipv6Resp,statusResp,gate_wayResp,dns_ipResp,macResp,uptimeResp,mtuResp,wan_mac = luci.util.get_lan_wan_info(interface)
	if resultResp ~= false then
		typeResp,mobile_typeResp,mobile_dev_usbResp,pppoe_nameResp,pppoe_passwdResp,static_ipResp,static_gwResp,static_dnsResp,static_dns2Resp,static_maskResp,macaddrResp,peerdnsResp,override_dnsResp,override_dns2Resp = luci.util.get_wan_contact_info()
	else 
		codeResp = 511
	end
	
	-- 物理网口或 interface 是否通
	is_eth_linkResp = luci.util.is_eth_link()
	
	-- 与互联网是否连通
	is_internet_linkResp = luci.util.is_internet_connect()
	
	--是否链接网线 (WAN 详细状态)
	local wan_status = luci.util.get_status_wan()
	
	-- 补丁如果取不到 mac
	if (macResp=="" or macResp == nil) and (macaddrResp=="" or macaddrResp == nil) then 
		local config_line = luci.util.execi("ifconfig")
		for l in config_line do
			local tmp1, tmp2, tmp3, tmp4, tmp5 = l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s]+)')	
			if tmp1 == s.global_wan_ifname() then 
				macResp = tmp5
			end
		end
	end
	
	if typeResp == "pppoe" then 
		mtuDefultResp = 1480
		if mtuResp == "" then 
			mtuResp = luci.util.trim(luci.util.exec("ifconfig pppoe-wan 2>/dev/null| grep MTU|sed 's/.*MTU://'|awk '{print $1}'"))
		end
	else 
		mtuDefultResp = 1500
		if mtuResp == "" then 
			mtuResp = luci.util.trim(luci.util.exec("ifconfig "..s.global_wan_ifname().." | grep MTU|sed 's/.*MTU://'|awk '{print $1}'"))
		end
	end
	
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	local special_dialResp = _uci_real:get("network", "wan", "special_dial")
	
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["type"] = typeResp
		arr_out_put["mobile_type"] = mobile_typeResp
		arr_out_put["mobile_dev_usb"] = mobile_dev_usbResp
		arr_out_put["pppoe_name"] = pppoe_nameResp
		arr_out_put["pppoe_passwd"] = pppoe_passwdResp
		arr_out_put["static_ip"] = static_ipResp
		arr_out_put["static_gw"] = static_gwResp
		arr_out_put["static_dns"] = static_dnsResp
		arr_out_put["static_dns2"] = static_dns2Resp
		arr_out_put["static_mask"] = static_maskResp
		arr_out_put["wan_status"] = wan_status
		arr_out_put["is_eth_link"] = is_eth_linkResp
		arr_out_put["is_internet_link"] = is_internet_linkResp
		arr_out_put["ipv4"] = ipv4Resp
		arr_out_put["ipv6"] = ipv6Resp
		arr_out_put["status"] = statusResp
		arr_out_put["gate_way"] = gate_wayResp
		arr_out_put["dns_ip"] = dns_ipResp
		arr_out_put["mac"] = macResp
		arr_out_put["macaddr"] = macaddrResp
		arr_out_put["mtu"] = mtuResp
		arr_out_put["mtu_defult"] = mtuDefultResp
		arr_out_put["uptime"] = uptimeResp
		arr_out_put["special_dial"] = special_dialResp
		arr_out_put["peerdns"] = peerdnsResp
		arr_out_put["override_dns"] = override_dnsResp
		arr_out_put["override_dns2"] = override_dns2Resp
		
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

function wan_restart()
	local output = {}

	os.execute("ubus call network reload")
	util.exec("hwf-at 5 'ifup wan'")

	output["data"] = ""
	output["msg"] = "wan restart success"
	output["code"] = "0"
	return output
end

function set_pppoe_param(data)
	
	-- 参数
	local pppoe_nameReq = data["pppoe_name"] 
	local pppoe_passwdReq = data["pppoe_passwd"]

	-- 返回值
	local output = {}

	if pppoe_nameReq == "" or pppoe_nameReq == nil or pppoe_passwdReq == "" or pppoe_passwdReq == nil then
		output["code"] = "1"
		output["msg"] = "param error"
		output["data"] = ""
		return output
	end

	local uci = require "luci.model.uci"
	local x  = uci.cursor()
 	x:set("network-conf","pppoe","interface")
 	x:set("network-conf", "pppoe", "pppoe_name", pppoe_nameReq)
 	x:set("network-conf", "pppoe", "pppoe_passwd", pppoe_passwdReq)
 	x:save("network-conf")
 	x:commit("network-conf")

	output["code"] = "0"
	output["msg"] = "set pppoe param success"
	output["data"] = ""
	return output
end

function get_pppoe_param()
	-- 返回值
	local output = {}
	local uci = require "luci.model.uci"
	local x  = uci.cursor()

	output["data"] = {}
	output["data"]["pppoe_name"] = x:get_all("network-conf","pppoe", "pppoe_name") or ""
	output["data"]["pppoe_passwd"] = x:get_all("network-conf","pppoe", "pppoe_passwd") or ""

	output["code"] = "0"
	output["msg"] = ""

	return output
end

function set_wan_type(data)
	-- 返回值
	local output = {}

	-- 数据
	local local_data = {}
	local pppoe = get_pppoe_param()["data"]

	local_data["type"] = data["type"]
	local_data["pppoe_name"] = pppoe["pppoe_name"]
	local_data["pppoe_passwd"] = pppoe["pppoe_passwd"]
	local_data["auto_restart"] = data["auto_restart"]

	output = set_wan_connect(local_data)

	return output
end

---------------------------------------------------------------------------------------
--	2.12 wan 设置链接方式
---------------------------------------------------------------------------------------
function set_wan_connect(data)
	
	-- 参数
	local typeReq = data["type"] or ""
	local mobile_typeReq = data["mobile_type"] or ""
	local mobile_dev_usbReq = data["mobile_dev_usb"] or ""
	local pppoe_nameReq = data["pppoe_name"] or ""
	local pppoe_passwdReq = data["pppoe_passwd"] or ""
	local static_ipReq = data["static_ip"] or ""
	local static_maskReq = data["static_mask"] or ""
	local static_gwReq = data["static_gw"] or ""
	local static_dnsReq = data["static_dns"] or ""
	local static_dns2Req = data["static_dns2"] or ""
	local special_dialReq = data["special_dial"] or ""
	local auto_restart = data["auto_restart"]
	
	-- 自定义 DNS
	local peerdnsReq = data["peerdns"] or ""
	local override_dnsReq = data["override_dns"] or ""
	local override_dns2Req = data["override_dns2"] or ""
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output={}
	
	-- 插入运算代码
	local tnetwork = require "luci.model.tnetwork".init()
	local tnetwork_defaults = tnetwork:get_defaults()
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()

	if typeReq == "mobile" then			-- 外接网卡 (需要判断设备类型，及是否接了 3g 模块)
	
		-- mobile_type 支持
		if mobile_typeReq == "10086" or  mobile_typeReq == "10000" or mobile_typeReq == "10010" then
			--判断是否上 3g 模块
			local mobile_dev_usb = luci.util.get_usb_device()
			if mobile_dev_usb ~= nil then 
				-- 判断，mobile_dev_usb 是否和设备取到的一样
				
				if (mobile_dev_usbReq == mobile_dev_usb) then 
					tnetwork_defaults:set("mobile_type",mobile_typeReq)
					tnetwork_defaults:set("mobile_dev_usb",mobile_dev_usbReq)
					proc_mobile(mobile_typeReq,mobile_dev_usbReq)
				else
					 codeResp = 516
				end
			else 
				codeResp = 515
			end
		else 
			codeResp = 517
		end 
		
	elseif typeReq == "pppoe" then			-- adsl 账号
	
		if pppoe_nameReq ~= "" and pppoe_nameReq ~= nil and pppoe_passwdReq ~= ""  and pppoe_passwdReq ~= nil then 
			tnetwork_defaults:set("pppoe_name",pppoe_nameReq)
			tnetwork_defaults:set("pppoe_passwd",pppoe_passwdReq)
			tnetwork_defaults:set("ifname",s.global_wan_ifname())
			tnetwork_defaults:set("peerdns",peerdnsReq)
			tnetwork_defaults:set("override_dns",override_dnsReq)
			tnetwork_defaults:set("override_dns2",override_dns2Req)
			
			--特殊拨号
			codeResp = proc_pppoe(pppoe_nameReq,pppoe_passwdReq,override_dnsReq,override_dns2Req,peerdnsReq)
			if special_dialReq == "1" then
				_uci_real:set("network", "wan", "special_dial", "1")
			else
				_uci_real:delete("network", "wan", "special_dial")
			end
			_uci_real:save("network")
			_uci_real:load("network")
			_uci_real:commit("network")
			_uci_real:load("network")
			
		else 
			codeResp = 518
		end
		
	elseif typeReq == "dhcp" then		-- dhcp 上链
	
		tnetwork_defaults:set("ip_type",typeReq)
		tnetwork_defaults:set("peerdns",peerdnsReq)
		tnetwork_defaults:set("override_dns",override_dnsReq)
		tnetwork_defaults:set("override_dns2",override_dns2Req)

		--codeResp = proc_ip(typeReq)	
		codeResp = proc_ip(typeReq,nil,nil,nil,override_dnsReq,override_dns2Req,peerdnsReq)
		
		_uci_real:delete("network", "wan", "special_dial")
		_uci_real:save("network")
		_uci_real:load("network")
		_uci_real:commit("network")
		_uci_real:load("network")
		
	elseif typeReq == "static" then		-- 静态 ip 账号
	
		local datatypes = require "luci.cbi.datatypes"	
		local interface = "lan"
		
		--判断是否在一个 ip 段
		local bit = require "bit"
		_,lanipv4 = luci.util.get_lan_wan_info(interface)
		local iptool = luci.ip
		local wanipnl = iptool.iptonl(static_ipReq)
		local wanmasknl = iptool.iptonl(static_maskReq)
		
		if not datatypes.ipaddr(static_ipReq) then
			codeResp = 512
		elseif not datatypes.ipaddr(static_gwReq) then 
			codeResp = 520	
		elseif not datatypes.ipaddr(static_dnsReq) then 
			codeResp = 519
		elseif not datatypes.ipaddr(static_maskReq) then 
			codeResp = 513
		elseif not (bit.band(iptool.iptonl(static_ipReq),iptool.iptonl(static_maskReq)) ~= bit.band(iptool.iptonl(lanipv4[1]['ip']),iptool.iptonl(static_maskReq)) and bit.band(iptool.iptonl(static_ipReq),iptool.iptonl(lanipv4[1]['mask'])) ~= bit.band(iptool.iptonl(lanipv4[1]['ip']),iptool.iptonl(lanipv4[1]['mask']))) then 
			-- (WANIP & WANMASK != LANIP & WANMASK) && (WANIP & LANMASK != LANIP & LANMASK)
			codeResp = 533
		elseif not ((wanipnl >= iptool.iptonl("1.0.0.0") and wanipnl <= iptool.iptonl("126.255.255.255")) or (wanipnl >= iptool.iptonl("128.0.0.0") and wanipnl <= iptool.iptonl("223.255.255.255"))) then 
			codeResp = 534
		elseif not (bit.band(wanipnl,iptool.ipnot(static_maskReq)) ~= 0 and bit.band(wanipnl,iptool.ipnot(static_maskReq)) ~= iptool.ipnot(static_maskReq)) then 
			-- ip & (~mask)不能为0，且ip & (~mask)不能为(~mask)
			codeResp = 535
		else 
			tnetwork_defaults:set("ip_type",typeReq)
			tnetwork_defaults:set("static_ip",static_ipReq)
			tnetwork_defaults:set("static_gw",static_gwReq)
			tnetwork_defaults:set("static_dns",static_dnsReq)
			tnetwork_defaults:set("static_dns2",static_dns2Req)
			tnetwork_defaults:set("static_mask",static_maskReq)				
			codeResp = proc_ip(typeReq,static_ipReq,static_maskReq,static_gwReq,static_dnsReq,static_dns2Req)
		end
		
		_uci_real:delete("network", "wan", "special_dial")
		_uci_real:save("network")
		_uci_real:load("network")
		_uci_real:commit("network")
		_uci_real:load("network")
	else 
		codeResp = 514
	end 

	-- 返回值及错误处理
	if (codeResp == 0) then 
		tnetwork_defaults:set("selected",typeReq)
		tnetwork:commit("tnetwork")
		tnetwork:save("tnetwork")
		
		-- 删除桥接
		local net = require "hiwifi.net"
		net.del_wifi_bridge()
	end

	if auto_restart == "1" then
		wan_restart()
	end

	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	2.13 获取移动 usb 是否链接状态
---------------------------------------------------------------------------------------

function get_mobile_dev_usb_status()
	
	-- 参数

	
	-- 返回值
	local statusResp
	local mobile_dev_usbResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local mobile_dev_usb = luci.util.get_usb_device()

	if mobile_dev_usb == nil then 
		statusResp = 0
		mobile_dev_usbResp = ""
	else 
		statusResp = 1
		mobile_dev_usbResp = mobile_dev_usb
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["status"] = statusResp
		arr_out_put["mobile_dev_usb"] = mobile_dev_usbResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.14 wan 口 mac 状态设置
---------------------------------------------------------------------------------------
function num2hex(num)
    local hexstr = '0123456789abcdef'
    local s = ''
    while num > 0 do
        local mod = math.fmod(num, 16)
        s = string.sub(hexstr, mod+1, mod+1) .. s
        num = math.floor(num / 16)
    end
    if s == '' then s = '0' end
    return s
end

function set_wan_mac(data)
	
	-- 参数

	local macReq = data["mac"]
	macReq = luci.util.format_mac(macReq)
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local need_rebootResp = 0
	local arr_out_put={}
	
	--插入运算代码
	local iface = "wan"
	local netmd = require "luci.model.network".init()
	local net = netmd:get_network(iface)
	mac_old = net:get_option_value("macaddr")

	-- 如果没变就不设置，不重启
	if luci.util.available_mac(macReq) or macReq=="" then 
		if mac_old ~= macReq or macReq=="" or macReq == nil then 
			-- 修改
			local datatypes = require "luci.cbi.datatypes"	
			if macReq == "" or macReq == nil then
				--默认 mac 为 lan mac +1
				local tnetwork = require "luci.model.tnetwork".init()
				local tnetwork_defaults = tnetwork:get_defaults()
				local mac_n = tnetwork_defaults:get("wan_mac")
	
				if mac_n == nil or mac_n == "" then 
					
					local tw = require "tw"
					local mac_o = tw.get_mac()
					mac_pre = string.sub(mac_o, 1, 7)
					mac_tail = string.sub(mac_o, 8, 12)
					
					local mac_tail_ = string.upper(num2hex(tonumber(mac_tail, 16)+1))
					mac_n = mac_pre..mac_tail_
					mac_n = string.sub(mac_n,1,2)..":"..string.sub(mac_n,3,4)..":"..string.sub(mac_n,5,6)..":"..string.sub(mac_n,7,8)..":"..string.sub(mac_n,9,10)..":"..string.sub(mac_n,11,12)
					
				end

				--自定义 兼容写法 ，如规则改变，则清空重启生效。
				if datatypes.macaddr(mac_n) then
					tnetwork_defaults:set("wan_mac",mac_n)
					tnetwork:commit("tnetwork")
					tnetwork:save("tnetwork")
					
					net:set("macaddr",mac_n)
				else
					net:set("macaddr","")
				end
			else  
				--自定义
				if datatypes.macaddr(macReq) then 
					net:set("macaddr",macReq)
				else 
					codeResp = 521
				end
			end 
		end
	else 
		codeResp = 538
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 

		luci.sys.call("env -i /bin/cp /etc/ppp/options.default /etc/ppp/options >/dev/null 2>/dev/null")
		luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
		netmd:commit("network")
		netmd:save("network")
		luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
		
		-- TODO: 执行一次 cat /tmp/resolv.conf.auto  为空， 无 DNS
		luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
	
		arr_out_put["need_reboot"] = need_rebootResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.15 wan 口 mtu 设置
---------------------------------------------------------------------------------------

function set_wan_mtu(data)
	
	-- 参数

	local mtuReq = data["mtu"]
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local need_rebootResp
	local arr_out_put={}
	
	--插入运算代码
	local iface = "wan"
	local netmd = require "luci.model.network".init()
	local net = netmd:get_network(iface)
	mtu_old = net:get_option_value("mtu")

	local typeResp = luci.util.get_wan_contact_info()
	local mtu_min = 576
	local mtu_max
	local rang_errorcode
	if typeResp == "pppoe" then 
		mtu_max = 1492
		rang_errorcode = 530
	else 
		mtu_max = 1500
		rang_errorcode = 531
	end
	
	-- 如果没变就不设置，不重启
	if mtuReq == "" or mtuReq == nil then
		codeResp = 522
	else 
		if mtu_old ~= mtuReq then 
			need_rebootResp = 1
	
			-- 修改
			local datatypes = require "luci.cbi.datatypes"
				--自定义
				
			if not tonumber(mtuReq) then 
				codeResp = rang_errorcode
			else 
				local mtuReq_num = tonumber(mtuReq)
				if mtuReq_num ~= nil then 	-- 判断是不是数字
					if mtuReq_num >= mtu_min and mtuReq_num <= mtu_max then
						net:set("mtu",mtuReq_num)
						luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
						netmd:commit("network")
						netmd:save("network")
						luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
					else 
						codeResp = rang_errorcode
					end
				else
					codeResp = 522			
				end 
			end
				
		else 
			need_rebootResp = 0
		end	
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["need_reboot"] = need_rebootResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	-- 重启
	--if (codeResp == 0) then
		--luci.sys.call("env -i /sbin/reboot & >/dev/null 2>/dev/null")
	--end
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.31 获取 dhcp (路由器分配ip)链接设备列表
---------------------------------------------------------------------------------------

function get_dhcp_device_list()
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local net = require "hiwifi.net"
	local devicesResp = net.get_dhcp_client_list()
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["devices"] = devicesResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
		
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.32 获取 dhcp 链接设备列表
--  0 为正常  -1 为连接中 ,其他数字为不正常
---------------------------------------------------------------------------------------

function get_pppoe_status()
	
	-- 参数

	-- 返回值
	local status_codeResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local fs = require "nixio.fs"
	local status,last_line,remote_message,special_dial,special_dial_num
	
	--[[

--插入运算代码
	local ppplog_mtime = tonumber(fs.stat("/var/log/ppp.log", "mtime"))
	local sys_time = tonumber(luci.util.exec("date +%s"))
	local ppplog_mtime_diff = sys_time - ppplog_mtime
	
	-- 靠 pid_exist 判断不准确，拨号中也有可能有此文件
	local status,last_line,remote_message,special_dial,special_dial_num = luci.util.get_pppoe_status()
		
	-- 有可能是刚断开还没写日志，需要n秒缓冲
	status = tonumber(status)
	
	if status == 0 and ppplog_mtime_diff < 10 then
	 	status=-1 
	elseif (status > 0 and ppplog_mtime_diff > 5) then
		status=-1
	end
	
]]--

	-- 靠 pid_exist 判断不准确，拨号中也有可能有此文件
	_,_,_,special_dial,special_dial_num = luci.util.get_pppoe_status()
	
	-- 命令行方式
	local wan_status = luci.util.get_status_wan()
	if wan_status['dev_up'] and  wan_status['dev_link'] and  wan_status['iface_up'] then 
		status = 0	--成功
	else
		if not wan_status['iface_up'] and wan_status['iface_pending'] then 	
			status = -1	--等待
			if wan_status['msg'] then
				remote_message = wan_status['msg']
			end
		else 
			status = 9999	--失败
			remote_message = wan_status['msg']
		end
	end
	
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["status_code"] = status
		-- arr_out_put["status_msg"] = luci.util.get_ppp_error(tonumber(status))
		-- arr_out_put["last_line"] = last_line
		arr_out_put["remote_message"] = remote_message
		arr_out_put["special_dial"] = special_dial
		arr_out_put["special_dial_num"] = special_dial_num
		arr_out_put["diff"] = ppplog_mtime_diff
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp

	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.33 获取 lan dhcp 状态
---------------------------------------------------------------------------------------

function get_lan_dhcp_status()
	
	-- 参数

	-- 返回值
	local startResp
	local limitResp
	local leasetimeResp
	local leasetime_numResp
	local leasetime_unitResp
	local ignoreResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	startResp = _uci_real:get("dhcp", "lan", "start")
	limitResp = _uci_real:get("dhcp", "lan", "limit")
	ignoreResp = _uci_real:get("dhcp", "lan", "ignore")
	
	leasetimeResp = _uci_real:get("dhcp", "lan", "leasetime")
	if ignoreResp ~= "1" then ignoreResp = "0" end
	leasetime_numResp,leasetime_unitResp = leasetimeResp:match("^(%d+)([^%d]+)")
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["start"] = startResp
		arr_out_put["limit"] = limitResp
		arr_out_put["leasetime"] = leasetimeResp
		arr_out_put["leasetime_num"] = leasetime_numResp
		arr_out_put["leasetime_unit"] = leasetime_unitResp
		arr_out_put["ignore"] = ignoreResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
	
end

---------------------------------------------------------------------------------------
--	2.34 设置 lan dhcp 状态
---------------------------------------------------------------------------------------

function set_lan_dhcp_status(data)
	
	-- 参数
	local startReq = tonumber(data["start"])
	local limitReq = tonumber(data["limit"])
	local endReq = tonumber(data["end"])
	local leasetimeReq = data["leasetime"]
	local ignoreReq = data["ignore"]
	
	local bind_ipReq={}
	local bind_macReq={}
	
	local datatypes = require "luci.cbi.datatypes"
	for i=1,5 do 
		bind_ipReq[i] = data["bind_ip"..i]
		bind_macReq[i] = luci.util.format_mac(data["bind_mac"..i])
	end  
	
	local tnum,tunit = leasetimeReq:match("^(%d+)([^%d]+)")
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	if (not datatypes.uinteger(startReq))
	or (not datatypes.integer(limitReq))
	or (tnum == nil)
	or (tunit ~= "h" and tunit ~="m") then 
		codeResp = 537
	else 
		tnum = tonumber(tnum)
		local endReq = startReq + limitReq - 1
		if startReq>endReq then 
			codeResp = 410
		elseif  startReq<1 or endReq>254 or endReq<1 or endReq>254  then 
			codeResp = 411
		elseif (tunit=="h" and (tnum<1 or tnum>48)) or (tunit=="m" and (tnum<2 or tnum>2880)) then 
			codeResp = 536
		else 
			local uci = require "luci.model.uci"
			_uci_real  = uci.cursor()
			
			_uci_real:set("dhcp", "lan", "start", startReq)
			_uci_real:set("dhcp", "lan", "limit", limitReq)
			_uci_real:set("dhcp", "lan", "leasetime", leasetimeReq)
			if ignoreReq == "1" then
				_uci_real:set("dhcp", "lan", "ignore", tonumber(ignoreReq))
			else 
				_uci_real:delete("dhcp", "lan", "ignore")
			end
			
			-- 设置  mac 地址绑定
			local uci_name
			for i=1,5 do 
				uci_name = "host_"..i
				os.execute("uci delete dhcp."..uci_name)
				if (datatypes.ip4addr(bind_ipReq[i]))
				and (datatypes.macaddr(bind_macReq[i])) then 
					-- change to _uci_real
					os.execute("uci set dhcp."..uci_name.."=host")
					os.execute("uci set dhcp."..uci_name..".ip="..bind_ipReq[i])
					os.execute("uci set dhcp."..uci_name..".mac="..bind_macReq[i])
				else 
					if (bind_ipReq[i] ~= "") or (bind_macReq[i] ~= "") then 
						codeResp = 548
					end
				end
			end
						
			_uci_real:save("dhcp")
			_uci_real:load("dhcp")
			_uci_real:commit("dhcp")
			_uci_real:load("dhcp")
		end
	end

	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	luci.util.exec("/etc/init.d/dnsmasq restart > /dev/null")
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.35 自动获取上网类型
---------------------------------------------------------------------------------------

function get_auto_wan_type()
	
	-- 参数

	-- 返回值
	local autowantypeResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	autowantypeResp = luci.util.get_auto_wan_type_code()
	if autowantypeResp == false then codeResp=99999 end

	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["autowantype"] = tonumber(autowantypeResp)
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.36 关闭 wan 口
---------------------------------------------------------------------------------------

function wan_shutdown()
	local iface = "wan"
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.37 重新链接 wan 口
---------------------------------------------------------------------------------------

function wan_reconect()
	
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local iface = "wan"
	
	--插入运算代码
	luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
	luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.38 网络诊断
---------------------------------------------------------------------------------------

function net_detect(data)
	
	-- 参数
	local dnotcheckwanReq = tonumber(data["dnotcheckwan"])
	
	-- 返回值
	local is_eth_linkResp
	local autowantypeResp
	local uciwantypeResp
	local dnsResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	--判断联网方式
	if is_bridge() then 
		is_eth_linkResp = 1
		uciwantypeResp = "wisp"
		autowantypeResp = 100
	else 
		if dnotcheckwanReq ~= 1 then 
			autowantypeResp = luci.util.get_auto_wan_type_code()
		end
		local interface = "wan"
		local resultResp = luci.util.get_lan_wan_info(interface)
		if resultResp ~= false then
			uciwantypeResp = luci.util.get_wan_contact_info()
		end
		
		-- Wan 口是否连通
		is_eth_linkResp = luci.util.is_eth_link();
		
	end
	
	-- 读取当前 DNS
	local status = require "luci.tools.status"
	dnsResp = status.dns_resolv()
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["is_eth_link"] = is_eth_linkResp
		arr_out_put["autowantype"] = autowantypeResp
		arr_out_put["uciwantype"] = uciwantypeResp
		arr_out_put["dns"] = dnsResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

function net_detect_website()
	local arr_out_put={}
	arr_out_put["baidu"] = {ping = net_detect_ping("www.baidu.com"),http = net_detect_http_request("www.baidu.com")}
	arr_out_put["qq"] = {ping = net_detect_ping("www.qq.com"),http = net_detect_http_request("www.qq.com")}
	arr_out_put["hiwifi_app"] = {ping = net_detect_ping("app.hiwifi.com"),http = net_detect_http_request("app.hiwifi.com"),https = net_detect_https_request("app.hiwifi.com")}
	--app.hiwifi.com
	--arr_out_put["taobao"]= net_detect_ping("www.taobao.com")
	--arr_out_put["weibo"] = net_detect_ping("www.weibo.com")
	--arr_out_put["ifeng"] = net_detect_ping("www.ifeng.com")
	
	return arr_out_put
end

function net_detect_byurl()
	local urlReq = data["url"]
	local arr_out_put={}
	local list = string.split(urlReq, "http://")
	list = string.split(list[#list], "https://")
	list = string.split(list[#list], "/")
	urlReq = list[1]
	local return_domain_name = urlReq:match("^[%w-.]+$")
	if return_domain_name then 
		arr_out_put["ping"] = net_detect_ping(return_domain_name)
		arr_out_put["http"] = net_detect_http_request(return_domain_name)
		local ips = luci.util.exec("nslookup '"..return_domain_name.."' |grep Address|cut -d' ' -f3|grep -v 127.0.0.1")
		arr_out_put["ip"] = string.gsub(ips, '\n', ", ")
	end

	return arr_out_put
end

--http_request
function net_detect_http_request(host)
  local t = {}
  local param = {
    url = "http://"..host
  }
  local ok, code, headers, status = socket_http.request(param)
  if ok ~= 1 then 
  	return false
  end
  return true
end

--https_request
function net_detect_https_request(host)
	local response_body = {}
    socket_https.request{
		url = "https://"..host,
		sink = ltn12.sink.table(response_body)
	}
	if response_body[1] then 
		return true
	end
	return false
end

function net_detect_ping(host)
	local cmd = "ping -c1 -W3 '"..host.."'"
	local data = luci.util.exec(cmd)
	if data==nil then
		return false
	end
	local findnum = string.find(data," 0%% packet loss")
	if  findnum~= nil and findnum then
		return true
	else
		return false
	end
end

---------------------------------------------------------------------------------------
--	2.39 获取 ppp keepalive 信息
---------------------------------------------------------------------------------------

function get_ppp_keepalive()
	
	-- 参数

	-- 返回值
	local lcp_intervalResp
	local lcp_failure_thresholResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	
	local reslut = _uci_real:get("network", "wan", "keepalive")
	if reslut and #reslut > 0 then
		lcp_intervalResp,lcp_failure_thresholResp = reslut:match("^(%d+)[ ,]+(%d+)")
	else 
		lcp_intervalResp = 5
		lcp_failure_thresholResp = 0
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["lcp_interval"] = lcp_intervalResp
		arr_out_put["lcp_failure_threshol"] = lcp_failure_thresholResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.39.2 获取 ppp adv 信息
---------------------------------------------------------------------------------------
function get_ppp_adv()
	
	-- 参数

	-- 返回值
	local wan_serviceResp
	local acResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	
	wan_serviceResp = _uci_real:get("network", "wan", "service")
	wan_acResp = _uci_real:get("network", "wan", "ac")
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["wan_service"] = wan_serviceResp
		arr_out_put["wan_ac"] = wan_acResp
		arr_out_put["ac"] = acResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.40 设置 ppp keepalive 信息
---------------------------------------------------------------------------------------

function set_ppp_keepalive(data)
	
	-- 参数
	--此值写死为 5
	--local lcp_intervalReq = data("lcp_interval")
	
	local lcp_failure_thresholReq = data["lcp_failure_threshol"]
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	
	if not tonumber(lcp_failure_thresholReq) then
		codeResp = 543
	else 
		local f = tonumber(lcp_intervalReq) or 5
		local i = tonumber(lcp_failure_thresholReq) or 0
		
		if i >  120 or i < 0 then 
			codeResp = 543
		else 
			if i > 0 then
				_uci_real:set("network", "wan", "keepalive", "%d %d" %{ f, i })
			else
				_uci_real:delete("network", "wan", "keepalive")
			end

			local iface = "wan"

			luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
			_uci_real:save("network")
			_uci_real:load("network")
			_uci_real:commit("network")
			_uci_real:load("network")
			luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
			
			--设置文件 此文件不需要更改
			--luci.util.edit_lcp_file(f)
		end
	end	

	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.40.2 设置取 ppp adv 信息
---------------------------------------------------------------------------------------
function set_ppp_adv()
--	
--	-- 参数
--
--	-- 返回值
--	local wan_serviceResp
--	local acResp
--	local codeResp = 0
--	local msgResp = ""
--	local arr_out_put={}
--	
--	--插入运算代码
--	local uci = require "luci.model.uci"
--	_uci_real  = uci.cursor()
--	
--	wan_serviceResp = _uci_real:get("network", "wan", "wan_service")
--	acResp = _uci_real:get("network", "wan", "ac")
	
	
	-- 参数
	local wan_serviceReq = data["wan_service"]
	local wan_acReq = data["wan_ac"]
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	_uci_real:set("network", "wan", "service", wan_serviceReq )
	_uci_real:set("network", "wan", "ac", wan_acReq )
	
	local iface = "wan"
	luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
	_uci_real:save("network")
	_uci_real:load("network")
	_uci_real:commit("network")
	_uci_real:load("network")
	luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.41 所有链接设备列表
---------------------------------------------------------------------------------------

function device_list()
	local device_names = require "hiwifi.device_names"
	
	-- 参数

	-- 返回值
	local devicesResp = {}
	local nameResp
	local ipResp
	local macResp
	local typeResp
	local signalResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	arr_out_put["data"] = {}
	
	--插入运算代码
	-- INFO: 以br找有线，以iw找无线，arp表只是以mac反查IP用
   	
   	devicesResp = luci.util.get_device_list_brief()
	local net = require "hiwifi.net"
	local mac_name_hash = {}
	
	--DHCP (获取 ip 及 name)
	local dhcp_mac_ip_hash = {}
	local dhcp_devicesResp = net.get_dhcp_client_list()
	if dhcp_devicesResp then
		for _, net in ipairs(dhcp_devicesResp) do 
			mac_name_hash[net['mac']] = net['name']
			dhcp_mac_ip_hash[net['mac']] = net['ip']
			if net['name'] then 
				local result_devicename = device_names.refresh(net['mac'],net['name'])
    		end
		end
    	
	end
	
	-- 别名列表 (会覆盖 dhcp 名称)
   	local re_name
	local device_names = require "hiwifi.device_names"
    local device_name_all = device_names.get_all()
    table.foreach(device_name_all, function(mac_one, re_name)
     	mac_name_hash[mac_one] = re_name
    end)
	
   	--arp 表 (获取 ip) ip 优先从这里取
	local arp_hash = {}
	local ip_one
	local mac_one
   	local arp_mac_ip_hash = {}
	luci.sys.net.arptable(function(arplist)
		if arplist['Flags'] == "0x2" and arplist['Device'] == "br-lan" then
			ip_one = arplist["IP address"]
			mac_one = normalize_mac(arplist["HW address"])
			arp_mac_ip_hash[mac_one] = ip_one
		end
	end)
	
	-- 拼接 name 及 ip
	for i, d in ipairs(devicesResp) do 
		devicesResp[i]['name'] = mac_name_hash[d['mac']]
		if arp_mac_ip_hash[d['mac']] then
			devicesResp[i]['ip'] = arp_mac_ip_hash[d['mac']]
		else 
			devicesResp[i]['ip'] = dhcp_mac_ip_hash[d['mac']]
		end 
	end
	
	-- 拼接上下行流量及限制
	local d_mac
	local traffic_mac_hash_v_t = traffic_mac_hash()
	local traffic_mac_hash_v = traffic_mac_hash_v_t['device']
	local traffic_qos_hash_v = traffic_qos_hash()
	
	for i, d in ipairs(devicesResp) do
		d_mac = devicesResp[i]['mac']
		if traffic_mac_hash_v[d_mac] then 
			devicesResp[i]['up'] = traffic_mac_hash_v[d_mac]['up']
			devicesResp[i]['down'] = traffic_mac_hash_v[d_mac]['down']
		else
			devicesResp[i]['up'] = 0
			devicesResp[i]['down'] = 0
		end
		
		devicesResp[i]['qos_status'] = 0
		if traffic_qos_hash_v[d_mac] then 
			devicesResp[i]['qos_up'] = traffic_qos_hash_v[d_mac]['up']
			devicesResp[i]['qos_down'] = traffic_qos_hash_v[d_mac]['down']
			devicesResp[i]['qos_status'] = 1
		end
	end	
	
	local mac_filter = require "hiwifi.mac_filter"
    local block_list_all = mac_filter.block_list()
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["data"]["devices"] = devicesResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp

	arr_out_put["data"]["total_up"] = traffic_mac_hash_v_t['total_up']
	arr_out_put["data"]["total_down"] = traffic_mac_hash_v_t['total_down']
	arr_out_put["data"]["block_cnt"] = table.getn(block_list_all);
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.41.2  被踢出的设备列表
---------------------------------------------------------------------------------------

function block_list()
	
	-- 参数

	-- 返回值
	local devicesResp = {}
	local nameResp
	local ipResp
	local macResp
	local typeResp
	local signalResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	-- 设备名称对照
	local mac_name_hash = {}
   	local re_name
	local device_names = require "hiwifi.device_names"
    local device_name_all = device_names.get_all()
    table.foreach(device_name_all, function(mac_one, re_name)
    	mac_one=luci.util.format_mac(mac_one)
     	mac_name_hash[mac_one] = re_name
    end)
	
	local mac_filter = require "hiwifi.mac_filter"
    local block_list_all = mac_filter.block_list()
   
    local name_one
	for _,mac_one in ipairs(block_list_all) do 
		mac_one =luci.util.format_mac(mac_one)
		if mac_name_hash[mac_one] then 
			name_one = mac_name_hash[mac_one]
		else 
			name_one = ""
		end
		
		table.insert(devicesResp, {
	      ['mac'] = mac_one,
	      ['type'] = "wifi",	--block type always wifi
	      ['name'] = name_one,
	    })
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["devices"] = devicesResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.41.2 恢复被踢除的设备
---------------------------------------------------------------------------------------

function remove_block()
	
	-- 参数

	-- 返回值
	local devicesResp = {}
	local nameResp
	local ipResp
	local macResp
	local typeResp
	local signalResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local mac_filter = require "hiwifi.mac_filter"
	
	local macsReq = data["macs"]
	local mac_list = string.split(macsReq, ",")
	for _, mac_one in ipairs(mac_list) do 
		mac_one = luci.util.format_mac(mac_one)
		mac_filter.allow_mac(mac_one)
	end
	
	--插入运算代码
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

function get_traffic_mac_hash()
	
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local traffic_mac_hash_v_t = traffic_mac_hash()
	local traffic_mac_hash_v = traffic_mac_hash_v_t['device']
	
	arr_out_put["traffic_mac_hash"] = traffic_mac_hash_v
	arr_out_put["total_up"] = traffic_mac_hash_v_t['total_up']
	arr_out_put["total_down"] = traffic_mac_hash_v_t['total_down']
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

function traffic_mac_hash()
	local traffic_mac_hash_v = {}
	local traffic_list = luci.util.get_traffic_list()
	local traffic_total = luci.util.get_traffic_total()
	local d_mac
	traffic_mac_hash_v['device'] = {}
	for i, d in ipairs(traffic_list) do
		if d['mac'] then 
			d_mac = normalize_mac(d['mac'])
			traffic_mac_hash_v['device'][d_mac] = {}
			traffic_mac_hash_v['device'][d_mac]['up'] = d['up']
			traffic_mac_hash_v['device'][d_mac]['down'] = d['down']
		end
	end
	traffic_mac_hash_v['total_up'] = traffic_total['up']
	traffic_mac_hash_v['total_down'] = traffic_total['down']
	return traffic_mac_hash_v
end

function traffic_qos_hash()
	local traffic_qos_hash_v = {}
	local device_qos = require "hiwifi.device_qos"
    local traffic_qos_all = device_qos.get_all()
    table.foreach(traffic_qos_all, function(mac_one, traff)
    	mac_one = normalize_mac(mac_one)
    	traffic_qos_hash_v[mac_one] = {}
     	traffic_qos_hash_v[mac_one]['up'] = traff['up']
     	traffic_qos_hash_v[mac_one]['down'] = traff['down']
     	traffic_qos_hash_v[mac_one]['name'] = traff['name']
    end)
	return traffic_qos_hash_v
end

---------------------------------------------------------------------------------------
--	2.42 强制设置设别名称
---------------------------------------------------------------------------------------

function set_device_name(data)
	
	-- 参数

	local nameReq = data["name"]
	local macReq = data["mac"]
	local datatypes = require "luci.cbi.datatypes"
	macReq = string.upper(macReq)
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	if not datatypes.macaddr(macReq) then 
		codeResp = 521
	elseif nameReq:len()>30 then
		codeResp = 546
	elseif nameReq == "" then 
		codeResp = 545
	else 
		local device_names = require "hiwifi.device_names"
    	local result_devicename = device_names.refresh(macReq,nameReq,true)
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["new_name"] = nameReq
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.44 获取 l2tp
---------------------------------------------------------------------------------------

function get_l2tp_vpn()
	
	-- 参数

	-- 返回值
	local usernameResp
	local passwordResp
	local protoResp
	local defaultrouteResp
	local autoResp
	local serverResp
	local statusResp = 1
	local switchResp = 1
	local defaultrouteResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}

	
	--插入运算代码
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	
	protoResp = _uci_real:get("network", l2tp_flag, "proto")
	
	usernameResp = _uci_real:get("network", l2tp_flag, "username")
	passwordResp = _uci_real:get("network", l2tp_flag, "password")
	serverResp = _uci_real:get("network", l2tp_flag, "server")
	
	defaultrouteResp = _uci_real:get("network", l2tp_flag, "defaultroute")
	autoResp = _uci_real:get("network", l2tp_flag, "auto")
	
	statusResp = luci.util.exec("/lib/vpn/vpn.sh status") 
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["proto"] = protoResp
		
		arr_out_put["username"] = usernameResp
		arr_out_put["password"] = passwordResp
		arr_out_put["server"] = serverResp
		
		arr_out_put["defaultroute"] = defaultrouteResp
		arr_out_put["auto"] = autoResp

		arr_out_put["status"] = statusResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.43 设置 l2tp
---------------------------------------------------------------------------------------

function set_l2tp_vpn(data)
	
	-- 参数
	local protoReq = data["proto"]
	
	local usernameReq = luci.util.trim(data["username"])
	local passwordReq = luci.util.trim(data["password"])
	local serverReq = luci.util.trim(data["server"])
		
	local defaultrouteReq = data["defaultroute"]
	local autoReq = data["auto"]
	
	if (autoReq == nil or autoReq == "") then 
		autoReq = "0"
	end

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	local uci = require "luci.model.uci"
	_uci_real  = uci.cursor()
	
	luci.util.exec("uci set network.vpn=interface")
	_uci_real:set("network", l2tp_flag, "proto",protoReq)
	
	_uci_real:set("network", l2tp_flag, "username",usernameReq)
	_uci_real:set("network", l2tp_flag, "password",passwordReq)
	_uci_real:set("network", l2tp_flag, "server",serverReq)
	
	_uci_real:set("network", l2tp_flag, "defaultroute",defaultrouteReq)
	_uci_real:set("network", l2tp_flag, "auto",autoReq)
	_uci_real:set("network", l2tp_flag, "peerdns",0)
	_uci_real:set("network", l2tp_flag, "pppd_options","refuse-eap")
	
	_uci_real:save("network")
	_uci_real:load("network")
	_uci_real:commit("network")
	_uci_real:load("network")
	
	
	local cmd_result = luci.util.exec("/lib/vpn/vpn.sh install")
	
	if (cmd_result == "error") then
		codeResp = 549
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put

end

function shutdown_l2tp_vpn()
	os.execute("/lib/vpn/vpn.sh stop")
	-- 参数
	local arr_out_put={}
	arr_out_put["code"] = 0
	return arr_out_put
end

function start_l2tp_vpn()
	os.execute("/lib/vpn/vpn.sh start")
	-- 参数
	local arr_out_put={}
	arr_out_put["code"] = 0
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.45 设置
---------------------------------------------------------------------------------------

function set_qos()
	
	-- 参数

	local macReq = string.upper(data["mac"])
	local upReq = data["up"]
	local downReq = data["down"]
	local nameReq = data["name"]
	local datatypes = require "luci.cbi.datatypes"
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	if not datatypes.macaddr(macReq) then
		codeResp = 521
	else 
		if tonumber(upReq) and tonumber(downReq) then 
		
			--保存
			local sets = require "hiwifi.collection.sets"
			local file_content = fs.readfile(DEVICE_QOS_FILE)
			local contant = {}
			if file_content ~= nil then
				for k in string.gmatch(file_content, "[^\n]+") do
					sets.add(contant, k)
				end
			end
			local have_set = false
			local lines = sets.to_list(contant)
			local lines_save = {}
			
			if tonumber(upReq)> -1 and tonumber(downReq)> -1 then 	--添加
				luci.util.exec('echo "'..macReq..' '..downReq..' '..upReq..'" >/proc/net/smartqos/config')
				
				--保存
				for _,l in pairs(lines) do
					local mac,up,down,name= l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s%s]+)')
					if mac == macReq then
						lines_save[#lines_save+1] = macReq.." "..downReq.." "..upReq.." "..nameReq
						have_set = true
					else 
						lines_save[#lines_save+1] = l
					end
				end
				if not have_set then
					lines_save[#lines_save+1] = macReq.." "..downReq.." "..upReq.." "..nameReq
				end
				fs.mkdirr(fs.dirname(DEVICE_QOS_FILE))
				fs.writefile(DEVICE_QOS_FILE, table.concat(lines_save, "\n"))
				
			elseif tonumber(upReq) == -1 and tonumber(downReq) == -1 then	--删除
				
				luci.util.exec('echo "'..macReq..' '..downReq..' '..upReq..'" >/proc/net/smartqos/config')
				
				--保存
				for _,l in pairs(lines) do
					local mac,up,down= l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)')
					if mac ~= macReq then
						lines_save[#lines_save+1] = l 
					end
				end
				fs.mkdirr(fs.dirname(DEVICE_QOS_FILE))
				fs.writefile(DEVICE_QOS_FILE, table.concat(lines_save, "\n"))
				
			else 
				codeResp = 550
			end
		else 
			codeResp = 550
		end 
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end

---------------------------------------------------------------------------------------
--	2.50 剔除可疑wifi 设备  (mac 地址限制)
---------------------------------------------------------------------------------------

function kick_device(data)
	
	-- 参数

	local macReq = data["mac"]
	local datatypes = require "luci.cbi.datatypes"	

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	if not datatypes.macaddr(macReq) then 
		codeResp = 521
	else 
		local mac_filter = require "hiwifi.mac_filter"
		local result = mac_filter.deny_mac(macReq)
		if not result then
			code = 99999
		end 
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["new_name"] = nameReq
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	return arr_out_put
end
