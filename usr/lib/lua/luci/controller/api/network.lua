--[[
	Info	网络设置 api
	Author	Wangchao  <wangchao123.com@gmail.com>
	Copyright	2012
]]--

module("luci.controller.api.network", package.seeall)

function index()

	local page   = node("api","network")
	page.target  = firstchild()
	page.title   = _("")
	page.order   = 120
	page.sysauth = "admin"
	page.sysauth_authenticator = "jsonauth"
	page.index = true

	entry({"api", "network"}, firstchild(), _(""), 120)
	entry({"api", "network", "get_lan_info"}, call("get_lan_info"), _(""), 121,true)
	entry({"api", "network", "set_lan_ip"}, call("set_lan_ip"), _(""), 122)
	entry({"api", "network", "get_wan_info"}, call("get_wan_info"), _(""), 123)
	entry({"api", "network", "set_wan_connect"}, call("set_wan_connect"), _(""), 124)
	entry({"api", "network", "get_mobile_dev_usb_status"}, call("get_mobile_dev_usb_status"), _(""), 125,true)
	entry({"api", "network", "set_wan_mac"}, call("set_wan_mac"), _(""), 126)
	entry({"api", "network", "set_wan_mtu"}, call("set_wan_mtu"), _(""), 127)
	entry({"api", "network", "get_dhcp_device_list"}, call("get_dhcp_device_list"), _(""), 128)
	entry({"api", "network", "get_pppoe_status"}, call("get_pppoe_status"), _(""), 129,true)
	entry({"api", "network", "get_lan_dhcp_status"}, call("get_lan_dhcp_status"), _(""), 130)
	entry({"api", "network", "set_lan_dhcp_status"}, call("set_lan_dhcp_status"), _(""), 131)
	entry({"api", "network", "get_auto_wan_type"}, call("get_auto_wan_type"), _(""), 132)
	entry({"api", "network", "wan_shutdown"}, call("wan_shutdown"), _(""), 133)
	entry({"api", "network", "wan_reconect"}, call("wan_reconect"), _(""), 134)
	entry({"api", "network", "net_detect"}, call("net_detect"), _(""), 135,true)
	entry({"api", "network", "net_detect_website"}, call("net_detect_website"), _(""), 140,true)
	entry({"api", "network", "get_ppp_keepalive"}, call("get_ppp_keepalive"), _(""), 136,true)
	entry({"api", "network", "get_ppp_adv"}, call("get_ppp_adv"), _(""), 136,true)
	entry({"api", "network", "set_ppp_keepalive"}, call("set_ppp_keepalive"), _(""), 137)
	entry({"api", "network", "set_ppp_adv"}, call("set_ppp_adv"), _(""), 137)
	entry({"api", "network", "device_list"}, call("device_list"), _(""), 138)
	entry({"api", "network", "block_list"}, call("block_list"), _(""), 146)
	entry({"api", "network", "remove_block"}, call("remove_block"), _(""), 147)
	entry({"api", "network", "get_traffic_mac_hash"}, call("get_traffic_mac_hash"), _(""), 138,true)
	entry({"api", "network", "set_device_name"}, call("set_device_name"), _(""), 139)
	entry({"api", "network", "net_detect_byurl"}, call("net_detect_byurl"), _(""), 140,true)
	entry({"api", "network", "set_l2tp_vpn"}, call("set_l2tp_vpn"), _(""),141)
	entry({"api", "network", "get_l2tp_vpn"}, call("get_l2tp_vpn"), _(""),142)
	entry({"api", "network", "shutdown_l2tp_vpn"}, call("shutdown_l2tp_vpn"), _(""),142)
	entry({"api", "network", "start_l2tp_vpn"}, call("start_l2tp_vpn"), _(""),141)
	entry({"api", "network", "status_l2tp_vpn"}, call("status_l2tp_vpn"), _(""),143)
	entry({"api", "network", "kick_device"}, call("kick_device"), _(""),144)
	entry({"api", "network", "set_qos"}, call("set_qos"), _(""), 145)
	entry({"api", "network", "get_speed_his_router_2d"}, call("get_speed_his_router_2d"), _(""), 146)
	entry({"api", "network", "get_time_his_device_list_2d"}, call("get_time_his_device_list_2d"), _(""), 147)
	entry({"api", "network", "get_speed_his_device_2d"}, call("get_speed_his_device_2d"), _(""), 148)
	entry({"api", "network", "get_time_his_device_2d"}, call("get_time_his_device_2d"), _(""), 149)
	entry({"api", "network", "net_detect_ping_remote"}, call("net_detect_ping_remote"), _(""), 160, true)
    entry({"api", "network", "net_detect_byurl_1"}, call("net_detect_byurl_1"), _(""), 151,true)
    entry({"api", "network", "device_signal"}, call("device_signal"), _(""), 150, true)
    entry({"api", "network", "net_detect_1"}, call("net_detect_1"), _(""), 136,true)
    entry({"api", "network", "device_list_rpt"}, call("device_list_rpt"), _(""), 139)
    entry({"api", "network", "device_rpt_info"}, call("device_rpt_info"), _(""), 160)
    entry({"api", "network", "find_pppoe_account"}, call("find_pppoe_account"), _(""), 160)
    entry({"api", "network", "check_pppoe_account"}, call("check_pppoe_account"), _(""), 160)
    entry({"api", "network", "get_inet_chk_state"}, call("get_inet_chk_state"), _(""), 160, true)
    entry({"api", "network", "inet_chk_switch"}, call("inet_chk_switch"), _(""), 160)

end

---------------------------------------------------------------------------------------
--	全局函数 变量
---------------------------------------------------------------------------------------

-- 获取 lan 口是否链接
local DEVICE_NAMES_FILE = "/etc/app/device_names"
local DEVICE_QOS_FILE = "/etc/app/device_qos"
local fs = require "nixio.fs"
local socket_http = require "socket.http"
local socket_https = require "ssl.https"
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
		luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
		netmd:commit("network")
		netmd:save("network")
		--在 set_wan_connect 的时候有过一次重启 ifup wan，这里不用
		--luci.sys.call("env -i /sbin/ifup %q >/dev/null 2>/dev/null" % iface)
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
		luci.sys.call("env -i /sbin/ifdown %q >/dev/null 2>/dev/null" % iface)
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
	local http = require "luci.http"
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
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put,true)
end

---------------------------------------------------------------------------------------
--	2.02 lan 设置局域网 ip
---------------------------------------------------------------------------------------

function set_lan_ip()
	local http = require "luci.http"
	
	-- 参数

	local ipReq = luci.http.formvalue("ip")
	--local maskReq = luci.http.formvalue("mask")
	
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
	http.write_json(arr_out_put,true)
	luci.http.close()
	
	-- 重启
	if (codeResp == 0) then
		luci.sys.call("env -i /sbin/reboot & >/dev/null 2>/dev/null")
	end
end

---------------------------------------------------------------------------------------
--	2.11 wan获取 互联网状态
---------------------------------------------------------------------------------------

function get_wan_info()
  local http = require "luci.http"
  
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
  local switch_status_wanResp
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  --插入运算代码
  local http = require "luci.http"
  
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
  
  switch_status_wanResp = get_switch_status_wan()
  
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
      mtuResp = luci.util.trim(luci.util.exec("ifconfig pppoe-wan | grep MTU|sed 's/.*MTU://'|awk '{print $1}'"))
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
    arr_out_put["switch_status_wan"] = switch_status_wanResp
    
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put,true)
end

---------------------------------------------------------------------------------------
--	2.12 wan 设置链接方式
---------------------------------------------------------------------------------------

function set_wan_connect()
  local http = require "luci.http"
  
  -- 参数

  local typeReq = luci.http.formvalue("type")
  local mobile_typeReq = luci.http.formvalue("mobile_type")
  local mobile_dev_usbReq = luci.http.formvalue("mobile_dev_usb")     
  local pppoe_nameReq = luci.http.formvalue("pppoe_name")
  local pppoe_passwdReq = luci.http.formvalue("pppoe_passwd")
  local static_ipReq = luci.http.formvalue("static_ip")
  local static_maskReq = luci.http.formvalue("static_mask")
  local static_gwReq = luci.http.formvalue("static_gw")
  local static_dnsReq = luci.http.formvalue("static_dns")
  local static_dns2Req = luci.http.formvalue("static_dns2")
  local special_dialReq = luci.http.formvalue("special_dial")
  
  -- 自定义 DNS
  local peerdnsReq = luci.http.formvalue("peerdns")
  local override_dnsReq = luci.http.formvalue("override_dns")
  local override_dns2Req = luci.http.formvalue("override_dns2")
  
  --WAN口速率和双工
  local switch_status_wanReq = luci.http.formvalue("switch_status_wan")
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  -- 插入运算代码
  
  local tnetwork = require "luci.model.tnetwork".init()
  local tnetwork_defaults = tnetwork:get_defaults()
  local uci = require "luci.model.uci"
  _uci_real  = uci.cursor()

  if typeReq == "mobile" then     -- 外接网卡 (需要判断设备类型，及是否接了 3g 模块)
  
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
    
  elseif typeReq == "pppoe" then      -- adsl 账号
  
    if pppoe_nameReq ~= "" and pppoe_nameReq ~= nil and pppoe_passwdReq ~= nil  and pppoe_passwdReq ~= nil then 
      tnetwork_defaults:set("pppoe_name",pppoe_nameReq)
      tnetwork_defaults:set("pppoe_passwd",pppoe_passwdReq)
      tnetwork_defaults:set("ifname",s.global_wan_ifname())
      tnetwork_defaults:set("peerdns",peerdnsReq)
      tnetwork_defaults:set("override_dns",override_dnsReq)
      tnetwork_defaults:set("override_dns2",override_dns2Req)
      switch_status_wan(switch_status_wanReq)
      
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
    
  elseif typeReq == "dhcp" then   -- dhcp 上链
  
    tnetwork_defaults:set("ip_type",typeReq)
    tnetwork_defaults:set("peerdns",peerdnsReq)
    tnetwork_defaults:set("override_dns",override_dnsReq)
    tnetwork_defaults:set("override_dns2",override_dns2Req)
    switch_status_wan(switch_status_wanReq)

    --codeResp = proc_ip(typeReq) 
    codeResp = proc_ip(typeReq,nil,nil,nil,override_dnsReq,override_dns2Req,peerdnsReq)
    
    _uci_real:delete("network", "wan", "special_dial")
    _uci_real:save("network")
    _uci_real:load("network")
    _uci_real:commit("network")
    _uci_real:load("network")
    
  elseif typeReq == "static" then   -- 静态 ip 账号
  
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
      switch_status_wan(switch_status_wanReq)
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
    
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  http.write_json(arr_out_put,true)
  os.execute("ifup wan")
  
  if typeReq == "static" then
    -- TODO: 执行一次 cat /tmp/resolv.conf.auto  为空， 无 DNS
    os.execute("ifup wan")
  end
  
  os.execute("killall wisp_chk.sh 1>/dev/null 2>1")
  
  --解决 自定义 dns 无效问题 (TODO: 桥接是否要加)
  os.execute("ubus call network reload")
    
--  修复 PPPoE 转为 DHCP 的 eth1 无 ip 问题，未成功，直接执行成功，脚本执行不成功
--  if  typeReq == "dhcp" then
--    luci.util.logger(os.execute("/etc/init.d/network stop && /etc/init.d/network start"))
--  end

end

function switch_status_wan(status)
  local STATUS_LIST = {'10half','10full','100half','100full','auto'}
  local find_status = nil
  if status ~= nil then
    for _, v in pairs(STATUS_LIST) do
      if v == status then
        find_status = v
        break
      end
    end
  else
    find_status = "auto"
  end
  if find_status ~= nil then
     local cmd = "switch status wan "..find_status.."; echo -n $?"
     local rst = luci.util.exec(cmd)
     if rst == "0" then
      luci.util.exec("touch /etc/config/switch_status && uci set switch_status.wan="..tostring(find_status).." && uci commit switch_status")
      return true
     end
  end
  return false
end

function get_switch_status_wan()
  local STATUS_LIST = {}
  STATUS_LIST['100full'] = 'WAN Port link:up 100Mb/s Full'
  STATUS_LIST['10full'] = 'WAN Port link:up 10Mb/s Full'
  STATUS_LIST['100half'] = 'WAN Port link:up 100Mb/s Half'
  STATUS_LIST['10half'] = 'WAN Port link:up 10Mb/s Half'
  STATUS_LIST['down'] = 'WAN Port link:down'
  local rst = luci.util.exec("switch status wan|awk -F '\\\n' '{printf $1}'")
  local find_status = nil
  for key, value in pairs(STATUS_LIST) do
    if value == rst then
      find_status = key
      break
    end
  end
  if find_status ~= nil then
    return find_status
  else
    return ""
  end
end

---------------------------------------------------------------------------------------
--	2.13 获取移动 usb 是否链接状态
---------------------------------------------------------------------------------------

function get_mobile_dev_usb_status()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put,true)
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

function set_wan_mac()
	local http = require "luci.http"
	
	-- 参数

	local macReq = luci.http.formvalue("mac")
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
	
	http.write_json(arr_out_put,true)
end

---------------------------------------------------------------------------------------
--	2.15 wan 口 mtu 设置
---------------------------------------------------------------------------------------

function set_wan_mtu()
	local http = require "luci.http"
	
	-- 参数

	local mtuReq = luci.http.formvalue("mtu")
	
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
	
	http.write_json(arr_out_put,true)
	luci.http.close()
	
	-- 重启
	--if (codeResp == 0) then
		--luci.sys.call("env -i /sbin/reboot & >/dev/null 2>/dev/null")
	--end
end

---------------------------------------------------------------------------------------
--	2.31 获取 dhcp (路由器分配ip)链接设备列表
---------------------------------------------------------------------------------------

function get_dhcp_device_list()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put,true)
end

---------------------------------------------------------------------------------------
--	2.32 获取 dhcp 链接设备列表
--  0 为正常  -1 为连接中 ,其他数字为不正常
---------------------------------------------------------------------------------------

function get_pppoe_status()
	local http = require "luci.http"
	
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

	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.33 获取 lan dhcp 状态
---------------------------------------------------------------------------------------

function get_lan_dhcp_status()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
	
end

---------------------------------------------------------------------------------------
--	2.34 设置 lan dhcp 状态
---------------------------------------------------------------------------------------

function set_lan_dhcp_status()
	local http = require "luci.http"
	
	-- 参数
	local startReq = tonumber(luci.http.formvalue("start"))
	local limitReq = tonumber(luci.http.formvalue("limit"))
	local endReq = tonumber(luci.http.formvalue("end"))
	local leasetimeReq = luci.http.formvalue("leasetime")
	local ignoreReq = luci.http.formvalue("ignore")
	
	local bind_ipReq={}
	local bind_macReq={}
	local bind_max = 20
	
	local datatypes = require "luci.cbi.datatypes"
	for i=1,bind_max do 
		bind_ipReq[i] = luci.http.formvalue("bind_ip"..i)
		bind_macReq[i] = luci.util.format_mac(luci.http.formvalue("bind_mac"..i))
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
			for i=1,bind_max do 
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
	
	http.write_json(arr_out_put)
	luci.util.exec("/etc/init.d/dnsmasq restart > /dev/null")
end

---------------------------------------------------------------------------------------
--	2.35 自动获取上网类型
---------------------------------------------------------------------------------------

function get_auto_wan_type()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.36 关闭 wan 口
---------------------------------------------------------------------------------------

function wan_shutdown()
	local http = require "luci.http"
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.37 重新链接 wan 口
---------------------------------------------------------------------------------------

function wan_reconect()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.38 网络诊断
---------------------------------------------------------------------------------------

function net_detect()
	local http = require "luci.http"
	
	-- 参数
	local dnotcheckwanReq = tonumber(luci.http.formvalue("dnotcheckwan"))
	
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
	
	http.write_json(arr_out_put)
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
	
	local http = require "luci.http"
	return http.write_json(arr_out_put)
end

function net_detect_byurl()
	local urlReq = luci.http.formvalue("url")
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

	local http = require "luci.http"
	return http.write_json(arr_out_put)
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
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.39.2 获取 ppp adv 信息
---------------------------------------------------------------------------------------
function get_ppp_adv()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.40 设置 ppp keepalive 信息
---------------------------------------------------------------------------------------

function set_ppp_keepalive()
	local http = require "luci.http"
	
	-- 参数
	--此值写死为 5
	--local lcp_intervalReq = luci.http.formvalue("lcp_interval")
	
	local lcp_failure_thresholReq = luci.http.formvalue("lcp_failure_threshol")
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.40.2 设置取 ppp adv 信息
---------------------------------------------------------------------------------------
function set_ppp_adv()
--	local http = require "luci.http"
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
	
	local http = require "luci.http"
	
	-- 参数
	local wan_serviceReq = luci.http.formvalue("wan_service")
	local wan_acReq = luci.http.formvalue("wan_ac")
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.41 所有链接设备列表
---------------------------------------------------------------------------------------

function device_list()
	local http = require "luci.http"
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
	local traffic_qos_hash_v = luci.util.traffic_qos_hash()
	
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
		arr_out_put["devices"] = devicesResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["total_up"] = traffic_mac_hash_v_t['total_up']
	arr_out_put["total_down"] = traffic_mac_hash_v_t['total_down']
	arr_out_put["block_cnt"] = table.getn(block_list_all);
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.41.2  被踢出的设备列表
---------------------------------------------------------------------------------------

function block_list()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.41.2 恢复被踢除的设备
---------------------------------------------------------------------------------------

function remove_block()
	local http = require "luci.http"
	
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
	
	local macsReq = luci.http.formvalue("macs")
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
	
	http.write_json(arr_out_put)
end

function get_traffic_mac_hash()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
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

---------------------------------------------------------------------------------------
--	2.42 强制设置设别名称
---------------------------------------------------------------------------------------

function set_device_name()
	local http = require "luci.http"
	
	-- 参数

	local nameReq = luci.http.formvalue("name")
	local macReq = luci.http.formvalue("mac")
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.44 获取 l2tp
---------------------------------------------------------------------------------------

function get_l2tp_vpn()
	local http = require "luci.http"
	
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.43 设置 l2tp
---------------------------------------------------------------------------------------

function set_l2tp_vpn()
	local http = require "luci.http"
	
	-- 参数
	local protoReq = luci.http.formvalue("proto")
	
	local usernameReq = luci.util.trim(luci.http.formvalue("username"))
	local passwordReq = luci.util.trim(luci.http.formvalue("password"))
	local serverReq = luci.util.trim(luci.http.formvalue("server"))
		
	local defaultrouteReq = luci.http.formvalue("defaultroute")
	local autoReq = luci.http.formvalue("auto")
	
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
	
	http.write_json(arr_out_put)
	luci.http.close()

end

function shutdown_l2tp_vpn()
	local http = require "luci.http"
	os.execute("/lib/vpn/vpn.sh stop")
	-- 参数
	local arr_out_put={}
	arr_out_put["code"] = 0
	http.write_json(arr_out_put)
	luci.http.close()
end

function start_l2tp_vpn()
	local http = require "luci.http"
	os.execute("/lib/vpn/vpn.sh start")
	-- 参数
	local arr_out_put={}
	arr_out_put["code"] = 0
	http.write_json(arr_out_put)
	luci.http.close()
end

---------------------------------------------------------------------------------------
--	2.45 设置
---------------------------------------------------------------------------------------

function set_qos()
	local http = require "luci.http"
	
	-- 参数

	local macReq = string.upper(luci.http.formvalue("mac"))
	local upReq = luci.http.formvalue("up")
	local downReq = luci.http.formvalue("down")
	local nameReq = luci.http.formvalue("name")
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.50 剔除可疑wifi 设备  (mac 地址限制)
---------------------------------------------------------------------------------------

function kick_device()
	local http = require "luci.http"
	
	-- 参数

	local macReq = luci.http.formvalue("mac")
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
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.51 获取 2 天的带宽历史   (日线页，上)
---------------------------------------------------------------------------------------

function get_speed_his_router_2d()
	local http = require "luci.http"
	
	-- 参数
	local cut_time = 300
	local his_td={}
	local his_ys={}
	local total_cnt = 3600*24/cut_time
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local cnt=1
	local speed_tmp
	local jump_tmp
	
	local t_time = luci.util.get_date_format()
	local y_time = luci.util.get_date_format(1)
	
	his_td = luci.util.get_traffic_day_total(t_time,cut_time)
	his_ys = luci.util.get_traffic_day_total(y_time,cut_time)

	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["his_td"] = his_td
	arr_out_put["his_ys"] = his_ys
	arr_out_put["cnt"] = total_cnt
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.52 获取 2 天的设备连接情况   (日线页，下)
---------------------------------------------------------------------------------------

function get_time_his_device_list_2d()
	local http = require "luci.http"
	local ios_client_ver = luci.http.formvalue("ios_client_ver")
	local android_client_ver = luci.http.formvalue("android_client_ver")
--  luci.util.logger(ios_client_ver)
--  luci.util.logger(android_client_ver)
	-- 参数
	local his_td={}
	local his_ys={}
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local t_time = luci.util.get_date_format()
	local y_time = luci.util.get_date_format(1)
	
	his_td = luci.util.get_time_his_device_list(t_time)
	his_ys = luci.util.get_time_his_device_list(y_time,true)

  local mac_filter = require "hiwifi.mac_filter"
  local block_list_all = mac_filter.block_list()
  
  --增加字段  block 字段
  for j=1,#his_td,1 do
    his_td[j]["is_block"] = 0;
    for i=1,#block_list_all,1 do
      if luci.util.format_mac(block_list_all[i]) == luci.util.format_mac(his_td[j]["mac"])  then
        his_td[j]["is_block"] = 1
      end
    end
  end
  
  for j=1,#his_ys,1 do
    his_ys[j]["is_block"] = 0;
    for i=1,#block_list_all,1 do
      if luci.util.format_mac(block_list_all[i]) == luci.util.format_mac(his_ys[j]["mac"])  then
        his_ys[i]["is_block"] = 1
      end
    end
  end

	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["his_td"] = his_td
	arr_out_put["his_ys"] = his_ys
	arr_out_put["block_cnt"] = table.getn(block_list_all);
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.53 获取 2 天的单设备带宽   (设备页，上)
---------------------------------------------------------------------------------------

function get_speed_his_device_2d()
	local http = require "luci.http"
	
	-- 参数
	local macReq = luci.http.formvalue("mac")
	local cut_time = 300
	local his_td={}
	local his_ys={}
	local total_cnt = 3600*24/cut_time
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local t_time = luci.util.get_date_format()
  local y_time = luci.util.get_date_format(1)
	
	his_td = luci.util.get_traffic_day_dev(macReq,t_time,cut_time)
	his_ys = luci.util.get_traffic_day_dev(macReq,y_time,cut_time)

	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["his_td"] = his_td
	arr_out_put["his_ys"] = his_ys
	arr_out_put["cnt"] = 288
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	2.54 获取 2 天的单设备连接时段  (设备页，下)
---------------------------------------------------------------------------------------

function get_time_his_device_2d()
	local http = require "luci.http"
	local macReq = luci.http.formvalue("mac")
	-- 参数
	local his_td={}
	local his_ys={}
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	local t_time = luci.util.get_date_format()
  local y_time = luci.util.get_date_format(1)
	
	his_td = luci.util.get_traffic_day_dev_range(macReq,t_time,300)
	his_ys = luci.util.get_traffic_day_dev_range(macReq,y_time,300)

	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["his_td"] = his_td
	arr_out_put["his_ys"] = his_ys
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  从路由ping设备
---------------------------------------------------------------------------------------
function net_detect_ping_remote()
  local http = require "luci.http"
  
  -- 参数
  local hostReq = luci.http.getenv("REMOTE_ADDR") 
  local countReq = 5
  local waitReq = 3

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local lossResp = 0
  local minResp = ""
  local avgResp = ""
  local maxResp = ""
  local remoteResp = ""
  local countResp = "";
  local arr_out_put={}
  
  --插入运算代码
  remoteResp = hostReq
  countResp = countReq
  hostReq = luci.util.fliter_unsafe(hostReq)
  
  local cmd = "ping -c'"..countReq.."' -W'"..waitReq.."' '"..hostReq.."'"
  local data = luci.util.exec(cmd)
  if data==nil then
    codeResp = 1
    lossResp = "100"
    msgResp = "ping failed"
  else
    minResp, avgResp, maxResp = string.match(data, " ([%d%.]+)/([%d%.]+)/([%d%.]+) ")
    lossResp = string.match(data, " (%d+)%% packet loss")
  end

  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["remote"] = remoteResp
  arr_out_put["loss"] = lossResp
  arr_out_put["min"] = minResp
  arr_out_put["avg"] = avgResp
  arr_out_put["max"] = maxResp
  arr_out_put["count"] = countResp
  
  http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  网络诊断 1.1  路由器到运营商
---------------------------------------------------------------------------------------

function net_detect_1()
  local http = require "luci.http"
  local net = require "hiwifi.net"
  local status = require "luci.tools.status"
  
  -- 参数
  local dnotcheckwanReq = tonumber(luci.http.formvalue("dnotcheckwan"))
  
  -- 返回值
  local is_eth_linkResp
  local isconnResp
  local isnetokResp
  local autowantypeResp
  local uciwantypeResp
  local dnsResp
  local maxUpResp = 0
  local maxDownResp = 0
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  --插入运算代码
  --判断联网方式
  if is_bridge() then 
    --is_eth_linkResp = 1
    uciwantypeResp = "wisp"
    autowantypeResp = 4
    --is_eth_linkResp = net.get_wifi_bridge_connect()
    is_eth_linkResp = net.get_wifi_bridge_connect();
    is_eth_linkResp = is_eth_linkResp or 0;
    --if not is_eth_linkResp then is_eth_linkResp = 0 end
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
  
  isconnResp = luci.util.is_internet_connect()
  if isconnResp == true or isconnResp == 1 or isconnResp == "1" then
    local baidu = net_detect_ping("www.baidu.com")
    local qq = net_detect_ping("www.qq.com")
    isnetokResp = baidu and qq
  end
  
  -- 读取当前 DNS
  dnsResp = status.dns_resolv()
  
  -- 仅取自定义dns，可优化
  local typeResp,mobile_typeResp,mobile_dev_usbResp,pppoe_nameResp,pppoe_passwdResp,static_ipResp,static_gwResp,static_dnsResp,static_dns2Resp,static_maskResp,macaddrResp,peerdnsResp,override_dnsResp,override_dns2Resp = luci.util.get_wan_contact_info()
  
  -- 最高上传和下载
  local traffic_list = luci.util.get_traffic_list()
  for i, d in ipairs(traffic_list) do
    if d['mac'] then 
      if (maxUpResp < tonumber(d['up'])) then
         maxUpResp = tonumber(d['up'])
      end
      if (maxDownResp < tonumber(d['down'])) then
         maxDownResp = tonumber(d['down'])
      end
    end
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["is_eth_link"] = is_eth_linkResp
    arr_out_put["isconn"] = isconnResp
    arr_out_put["isnetok"] = isnetokResp
    arr_out_put["autowantype"] = autowantypeResp
    arr_out_put["uciwantype"] = uciwantypeResp
    arr_out_put["dns"] = dnsResp
    arr_out_put["peerdns"] = peerdnsResp
    arr_out_put["override_dns"] = override_dnsResp
    arr_out_put["override_dns2"] = override_dns2Resp
    arr_out_put["static_dns"] = static_dnsResp
    arr_out_put["static_dns2"] = static_dns2Resp
    arr_out_put["max_up"] = maxUpResp
    arr_out_put["max_down"] = maxDownResp
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  根据mac地址查询信号强度
---------------------------------------------------------------------------------------

function device_signal()
  local http = require "luci.http"
  
  -- 参数
  local macReq = luci.http.formvalue("mac")
  local datatypes = require "luci.cbi.datatypes"  

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local signalResp = ""
  local typeResp = ""
  local nameResp = ""
  local arr_out_put={}
  
  --插入运算代码
  if not datatypes.macaddr(macReq) then 
    codeResp = 521
  else
    macReq = normalize_mac(macReq)
    local device_list_brief = luci.util.get_device_list_brief()
    for i, d in ipairs(device_list_brief) do 
      if d['mac'] == macReq then
        signalResp = d['signal']
        typeResp = d['type']
        break
      end
    end
    
    local net = require "hiwifi.net"
    
    --DHCP (获取 ip 及 name)
    local dhcp_mac_ip_hash = {}
    local dhcp_devicesResp = net.get_dhcp_client_list()
    if dhcp_devicesResp then
      for _, net in ipairs(dhcp_devicesResp) do 
        if net['mac'] == macReq and net['name'] then 
          nameResp = net['name']
          break
        end
      end
    end
    
    -- 别名列表 (会覆盖 dhcp 名称)
    local re_name
    local device_names = require "hiwifi.device_names"
    local device_name_all = device_names.get_all()
    table.foreach(device_name_all, function(mac_one, re_name)
      if mac_one == macReq then
        nameResp = re_name
      end
    end)
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["name"] = nameResp
    arr_out_put["type"] = typeResp
    arr_out_put["signal"] = signalResp
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  根据url检测ping/http/https
---------------------------------------------------------------------------------------
function net_detect_byurl_1()
  local http = require "luci.http"
  
  -- 参数
  local urlReq = luci.http.formvalue("url")
  local pingReq = luci.http.formvalue("ping")
  local httpReq = luci.http.formvalue("http")
  local httpsReq = luci.http.formvalue("https")
  
  -- 返回值
  local codeResp = 0;
  local msgResp = ""
  local pingResp = "";
  local httpResp = "";
  local httpCodeResp = "";
  local httpStatusResp = "";
  local httpsResp = "";
  local arr_out_put={}
  
  --插入运算代码
  local list = string.split(urlReq, "http://")
  list = string.split(list[#list], "https://")
  list = string.split(list[#list], "/")
  urlReq = list[1]
  local return_domain_name = urlReq:match("^[%w-.]+$")
  if return_domain_name then
    if (pingReq == true or pingReq == 'true') then
      pingResp = net_detect_ping(return_domain_name)
    end
    if (httpReq == true or httpReq == 'true') then
      httpResp, httpCodeResp, httpStatusResp = net_http_request(return_domain_name)
    end
    if (httpsReq == true or httpsReq == 'true') then
      httpsResp = net_detect_https_request(return_domain_name)
    end
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["ping"] = pingResp
    arr_out_put["http"] = httpResp
    arr_out_put["httpCode"] = httpCodeResp
    arr_out_put["httpStatus"] = httpStatusResp
    arr_out_put["https"] = httpsResp
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  return http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  获取所有设备的mac, name, ip
---------------------------------------------------------------------------------------
function get_all_mac_name_ip()
    local net = require "hiwifi.net"
    local device_names = require "hiwifi.device_names"
  
    local all_mac_name_ip_list = {}
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
    
    table.foreach(mac_name_hash, function(mac, name)
      local name = name
      local ip
      if arp_mac_ip_hash[mac] then
        ip = arp_mac_ip_hash[mac]
      else 
        ip = dhcp_mac_ip_hash[mac]
      end
      local dev = {}
      dev['mac'] = mac
      dev['name'] = name
      dev['ip'] = ip
      table.insert(all_mac_name_ip_list, dev)
    end)
    return all_mac_name_ip_list
end

---------------------------------------------------------------------------------------
--  极卫星列表
---------------------------------------------------------------------------------------
function device_list_rpt()
  local http = require "luci.http"
  local device_names = require "hiwifi.device_names"
  local net = require "hiwifi.net"
  local device_names = require "hiwifi.device_names"
  local mac_filter = require "hiwifi.mac_filter"
  
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
  local wifi_client_list = luci.util.get_wifi_client_list()
  for i, d in ipairs(wifi_client_list) do 
    if d['rpt'] then
      table.insert(devicesResp, d)
    end
  end
  
  -- 拼接 name 及 ip
  local all_mac_name_ip = get_all_mac_name_ip()
  for i, d in ipairs(devicesResp) do 
    for j, mac_name_ip in ipairs(all_mac_name_ip) do 
      if mac_name_ip['mac'] == d['mac'] then
        devicesResp[i]['name'] = mac_name_ip['name']
        devicesResp[i]['ip'] = mac_name_ip['ip']
        devicesResp[i]['online'] = net_detect_ping(devicesResp[i]['ip']);
        --暂不支持说去固件版本
        devicesResp[i]['build'] = ''
      end
    end
    
    devicesResp[i]['online'] = net_detect_ping(devicesResp[i]['ip']);
  end
    
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["devices"] = devicesResp
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  极卫星信息
---------------------------------------------------------------------------------------
function device_rpt_info()
  local http = require "luci.http"
  local device_names = require "hiwifi.device_names"
  
  
  -- 参数
  local macReq = luci.http.formvalue("mac")
  macReq = luci.util.format_mac(macReq)

  -- 返回值
  local devicesResp = {}
  local nameResp
  local ipResp
  local macResp
  local typeResp
  local signalResp
  local buildResp
  local rptResp
  local onlineResp
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  --插入运算代码
  if macReq ~= nil and luci.util.available_mac(macReq) then
    local wifi_client_list = luci.util.get_wifi_client_list()
    for i, d in ipairs(wifi_client_list) do 
      if d['rpt'] then
        if d['mac'] == macReq then
          macResp = d['mac']
          table.insert(devicesResp, d)
        end
      end
    end
  else
    codeResp = 538
  end
  
  if codeResp == 0 and macResp == nil then
    codeResp = 610
  end
  
  if codeResp == 0 then
    local all_mac_name_ip = get_all_mac_name_ip()
    -- 拼接 name 及 ip
    for i, d in ipairs(devicesResp) do 
      for j, mac_name_ip in ipairs(all_mac_name_ip) do 
        if mac_name_ip['mac'] == d['mac'] then
          devicesResp[i]['name'] = mac_name_ip['name']
          devicesResp[i]['ip'] = mac_name_ip['ip']
        end
      end
      
      -- 是否在线 及 rom版本
      devicesResp[i]['online'] = net_detect_ping(devicesResp[i]['ip']);
      devicesResp[i]['build'] = ''
      if devicesResp[i]['online'] then
        local data = luci.util.get_dev_build(devicesResp[i]['ip'])
        if data ~= nil then
          devicesResp[i]['build'] = data
        end
      end
    end
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then
    if table.getn(devicesResp) > 0 then
      for i, d in ipairs(devicesResp) do 
        arr_out_put["mac"] = devicesResp[i]['mac']
        arr_out_put["type"] = devicesResp[i]['type']
        arr_out_put["name"] = devicesResp[i]['name']
        arr_out_put["build"] = devicesResp[i]['build']
        arr_out_put["rpt"] = devicesResp[i]['rpt']
        arr_out_put["online"] = devicesResp[i]['online']
        arr_out_put["signal"] = devicesResp[i]['signal']
        arr_out_put["ip"] = devicesResp[i]['ip']
      end
    end 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put)
end

--http_request
function net_http_request(host)
  local t = {}
  local param = {
    url = "http://"..host
  }
  local ok, code, headers, status = socket_http.request(param)
  return ok, code, status
end

-- find_pppoe_account
function find_pppoe_account()
  local http = require "luci.http"
  
  -- 参数
  local timeoutReq = luci.http.formvalue("timeout")
  if timeoutReq == nil then
    timeoutReq = 65
  else
    timeoutReq = tonumber(timeoutReq)
    if timeoutReq < 0 or timeoutReq > 3600 then
      timeoutReq = 65
    end
  end
  
  -- 返回值
  local codeResp = 0;
  local msgResp = ""
  local usernameResp = "";
  local passwordResp = "";
  local arr_out_put={}
  
  --插入运算代码
  os.execute("/sbin/pppoe-sniffer.sh '"..timeoutReq.."' &")
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["start"] = 1
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  return http.write_json(arr_out_put)
end

-- check_pppoe_account
function check_pppoe_account()
  local http = require "luci.http"
  
  -- 参数
  
  -- 返回值
  local codeResp = 0;
  local msgResp = ""
  local usernameResp = "";
  local passwordResp = "";
  local arr_out_put={}
  
  --插入运算代码
  local pppoe_key = luci.util.exec("cat /tmp/pppoe-sniffer/pppoe.key 2>/dev/null");
  if pppoe_key ~= nil and pppoe_key ~= "" then
      local pppoe_info = string.split(pppoe_key, "\n")
      if pppoe_info[1] ~= nil then
          usernameResp = pppoe_info[1]
      end
      if pppoe_info[2] ~= nil then
          passwordResp = pppoe_info[2]
      end
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["username"] = usernameResp
    --arr_out_put["password"] = passwordResp
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  return http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  自动网络诊断状态
---------------------------------------------------------------------------------------
function get_inet_chk_state()
  local http = require "luci.http"
  
  -- 参数
  
  -- 返回值
  local codeResp = 0;
  local msgResp = ""
  local state = ""
  local arr_out_put={}
  
  --插入运算代码
  local state_code = luci.util.exec("/usr/bin/inet_chk_switch state");
  if state_code == "off\n" then
    state = "off"
  elseif state_code == "on\n" then
    state = "on"
  else
    codeResp = 532
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then
    arr_out_put["state"] = state
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  return http.write_json(arr_out_put, true)
end

---------------------------------------------------------------------------------------
--  网络诊断开关
---------------------------------------------------------------------------------------
function inet_chk_switch()
  local http = require "luci.http"
  
  -- 参数
  local cmdReq = http.formvalue("cmd")
  local timeoutReq = http.formvalue("timeout")
  
  -- 返回值
  local codeResp = 0;
  local msgResp = ""
  local arr_out_put={}

  --插入运算代码
  if cmdReq == "on" or cmdReq == "off" then
    local cmd = cmdReq
    local timeout = ""
    if timeoutReq ~= nil and tonumber(timeoutReq) > 0 then
      timeout = tonumber(timeoutReq)
    end
    local todo = "/usr/bin/inet_chk_switch "..cmd.." "..timeout.."; echo -n $?"
    local rst = luci.util.exec(todo)
    if rst ~= 0 and rst ~= "0" then
      codeResp = 532
    end
  else
    codeResp = 100
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then
    arr_out_put["state"] = cmdReq
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  return http.write_json(arr_out_put)
end
