local json = require('hiwifi.json')
local firmware_info = "/tmp/upgrade_firmware_info.txt"
local clinet_token = "/tmp/clinet_token"
local firmware_md5_path = "/tmp/upgrade_firmware_md5"
local firmware_filename = '/tmp/firmware.img'
local led_disable_file = '/etc/config/led_disable'
local remote_script_enable_file = '/etc/config/remote_script_enable'
--local upgrade_check_url = 'http://cloud.turboer.com/api/latest_rom'
local firmware_key = "pejlwcc4lfak";
local fs  = require "luci.fs"

local socket_http = require("socket.http")
local ltn12 = require("ltn12")
local protocol = require "luci.http.protocol"
local tw = require "tw"
local hiwifi = require "hiwifi.firmware"
local hiwifi_conf = require "hiwifi.conf"
local mode_path = "/etc/nginx/mode"
local datatypes = require "luci.cbi.datatypes"

local upgrade_cache_folder = hiwifi_conf.firmware_path.."/" --当前设备保证有足够空间的目录路径
local rom_file = "rom.bin" --rom 文件名


module("openapi.system.os", package.seeall)

function reboot()
	-- 参数

	-- 返回值
	local output = {}
	
	os.execute("/usr/sbin/hwf-at 5 reboot")

	-- 返回值及错误处理
	output["code"] = "0"
	output["msg"] = ""
	output["data"] = ""

	return output
end

---------------------------------------------------------------------------------------
--	1.07 恢复出厂设置
---------------------------------------------------------------------------------------
function reset_all()
	-- 参数

	-- 返回值
	local output = {}
	
	os.execute("/usr/sbin/hwf-at 5 '/sbin/firstboot && /sbin/reboot & >/dev/null 2>/dev/null'")

	-- 返回值及错误处理
	output["code"] = "0"
	output["msg"] = "reset success"
	output["data"] = ""

	return output
end

function get_info()
	local tw = require "tw"
	local fs = require "nixio.fs"
	local no_auto_bind = "/etc/app/no_auto_bind"
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local issetsafe = 0
	local output = {}
	--插入运算代码
	local HAVESETSAFE_V = luci.util.get_agreement("HAVESETSAFE")
	local auto_bind=0
	
  if HAVESETSAFE_V == 0 or HAVESETSAFE_V == "0" then
    issetsafe = 0
  else 
    issetsafe = 1
  end
  
  -- 是否弹出 auto_bind
  if fs.access(no_auto_bind) then
    auto_bind=1
    fs.remove(no_auto_bind) 
  end
  
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["mac"] = tw.get_mac()
		arr_out_put["sys_board"] = luci.util.get_sys_board()
		arr_out_put["version"] = tw.get_version():match("^([^%s]+)")
		arr_out_put["support_client_bind"] = 1
		arr_out_put["issetsafe"] = issetsafe  --判断是否走完首次安装设置安全的流程 0 为未设置
		arr_out_put["auto_bind"] = auto_bind --判断是否走完首次安装设置安全的流程 0 为未设置
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	设置系统密码
---------------------------------------------------------------------------------------

function set_password(data)
	-- 参数
	local passwordReq = data["password"]
	local old_passwordReq = data["old_password"]

	local sys = require("luci.sys")
	local checkpass = luci.sys.user.checkpasswd("root", old_passwordReq)
	if passwordReq ~= nil then
	 passwordReq = luci.util.trim(passwordReq)
	end
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local stat = nil
	local output = {}
	
	--插入运算代码
	if passwordReq == nil or passwordReq == "" then
		codeResp = 301
	elseif not checkpass then
		codeResp = 302
	elseif passwordReq:len()<5 or passwordReq:len()>64 then
		codeResp = 303
	else  
		stat = luci.sys.user.setpasswd("root", passwordReq)
		if stat~=0 then
			codeResp = 1000
		end 
	end
	
	-- 返回值及错误处理
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.11 路由器资源情况
---------------------------------------------------------------------------------------

function nbrinfo()
	-- 参数

	-- 返回值
	local systemResp
	local memtotalResp
	local memcachedResp
	local membuffersResp
	local memfreeResp
	local conn_maxResp
	local conn_countResp
	local loadavgResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码
	local sys = require("luci.sys")
	local system, model, memtotal, memcached, membuffers, memfree = luci.sys.sysinfo()
	local conn_count = tonumber((
			luci.sys.exec("wc -l /proc/net/nf_conntrack") or
			luci.sys.exec("wc -l /proc/net/ip_conntrack") or
			""):match("%d+")) or 0
	local conn_max = tonumber((
			luci.sys.exec("sysctl net.nf_conntrack_max") or
			luci.sys.exec("sysctl net.ipv4.netfilter.ip_conntrack_max") or
			""):match("%d+")) or 4096
		
	systemResp=system
	memtotalResp=memtotal
	memcachedResp=memcached
	membuffersResp=membuffers
	memfreeResp=memfree
	conn_maxResp=conn_max
	conn_countResp=conn_count
	loadavgResp={sys.loadavg()}
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["system"] = systemResp
		arr_out_put["memtotal"] = memtotalResp
		arr_out_put["memcached"] = memcachedResp
		arr_out_put["membuffers"] = membuffersResp
		arr_out_put["memfree"] = memfreeResp
		arr_out_put["conn_max"] = conn_maxResp
		arr_out_put["conn_count"] = conn_countResp
		arr_out_put["loadavg"] = {}
		arr_out_put["loadavg"] = loadavgResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end
