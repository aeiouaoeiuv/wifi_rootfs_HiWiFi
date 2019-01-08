--[[
	Info	api 系统
	Author	Wangchao  <wangchao123.com@gmail.com>
	Copyright	2012
]]--

module("openapi.system.sys", package.seeall)

--[[
	entry({"api", "system", "get_lang_list"}, call("get_lang_list"), _(""), 102,true)
	entry({"api", "system", "get_lang"}, call("get_lang"), _(""), 103,true)
	entry({"api", "system", "set_lang"}, call("set_lang"), _(""), 104)
	entry({"api", "system", "set_sys_password"}, call("set_sys_password"), _(""), 105)
	entry({"api", "system", "reboot"}, call("reboot"), _(""), 106)
	entry({"api", "system", "reset_all"}, call("reset_all"), _(""), 107)
	entry({"api", "system", "upgrade_check"}, call("upgrade_check"), _(""), 108,true)
	entry({"api", "system", "upgrade_download"}, call("upgrade_download"), _(""), 109,true)
	entry({"api", "system", "upgrade_flash"}, call("upgrade_flash"), _(""), 110,true)
	entry({"api", "system", "nbrinfo"}, call("nbrinfo"), _(""), 111)
	entry({"api", "system", "usbinfo"}, call("usbinfo"), _(""), 112)
	entry({"api", "system", "set_guide_cache"}, call("set_guide_cache"), _(""), 113)
	entry({"api", "system", "upgrade_download_percent"}, call("upgrade_download_percent"), _(""), 114,true)
	entry({"api", "system", "is_internet_connect"}, call("is_internet_connect"), _(""), 118,true)
	entry({"api", "system", "check_network_connect"}, call("check_network_connect"), _(""), 119,true)
	entry({"api", "system", "set_systime"}, call("set_systime"), _(""), 120)
	entry({"api", "system", "format_disk"}, call("format_disk"), _(""), 121)
	entry({"api", "system", "set_led_status"}, call("set_led_status"), _(""), 122)
	entry({"api", "system", "get_led_status"}, call("get_led_status"), _(""), 123)
	entry({"api", "system", "do_client_bind"}, call("do_client_bind"), _(""), 124)
	entry({"api", "system", "set_nginx_mode"}, call("set_nginx_mode"), _(""), 125)
	entry({"api", "system", "get_nginx_mode"}, call("get_nginx_mode"), _(""), 126)
	entry({"api", "system", "set_remote_script"}, call("set_remote_script"), _(""), 127)
	entry({"api", "system", "get_sd_status"}, call("get_sd_status"), _(""), 128)
	entry({"api", "system", "check_sd_status"}, call("check_sd_status"), _(""), 129)
	entry({"api", "system", "backup_user_conf_1"}, call("backup_user_conf_1"), _(""), 131)
	entry({"api", "system", "restore_user_conf_1"}, call("restore_user_conf_1"), _(""), 132)
	entry({"api", "system", "backup_info_1"}, call("backup_info_1"), _(""), 132)
	entry({"api", "system", "sd_state"}, call("sd_state"), _(""), 132, true)
	entry({"api", "system", "sd_manual_part"}, call("sd_manual_part"), _(""), 132)
	entry({"api", "system", "sd_size_check"}, call("sd_size_check"), _(""), 132)
	entry({"api", "system", "cloud_debug"}, call("cloud_debug"), _(""), 133)
]]--
---------------------------------------------------------------------------------------
--	全局函数 变量
---------------------------------------------------------------------------------------

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
local json = require("luci.tools.json")
local protocol = require "luci.http.protocol"
local tw = require "tw"
local hiwifi = require "hiwifi.firmware"
local hiwifi_conf = require "hiwifi.conf"
local mode_path = "/etc/nginx/mode"
local datatypes = require "luci.cbi.datatypes"

--config
--local devname   = "sda1"	--存储磁盘设备名称

local upgrade_cache_folder = hiwifi_conf.firmware_path.."/" --当前设备保证有足够空间的目录路径
local rom_file = "rom.bin" --rom 文件名

--创建升级文件夹
-- (弃用)
function get_upgrade_cache_ver()
	local ln
	if nixio.fs.access(upgrade_cache_folder) == nil then
		os.execute("mkdir -p %q" % upgrade_cache_folder)				
	end
	if nixio.fs.access(upgrade_cache_folder..rom_info_file) == nil or
		nixio.fs.access(upgrade_cache_folder..rom_file) == nil then
		return ""
	else
		local fd =  io.open(upgrade_cache_folder..rom_info_file, "r")
		while true do
			local ln = fd:read("*l")
			
			if not ln then
				break
			else
				local ln = luci.util.trim(ln)
			end
		end
		fd:close() 
		return ln
	end
end

-- fp_thumb:write(chunk) 

--解析 firmware_info 文件格式
function get_data_value(str, name)
	local c = string.gsub(";" .. (str or "") .. ";", "%s*;%s*", ";")
  	local p = ";" .. name .. "=(.-);"
  	local i, j, value = c:find(p)
  	return value 
end

-- 读取 firmware_md5 用于检查合法性
function get_firmware_md5()
	local data = fs.readfile(firmware_md5_path)
	if data and data~="" then
		return data
	else
		return ""
	end
end

-- 写 firmware_md5 用于检查合法性
function set_firmware_md5(md5)
	fd = io.open(firmware_md5_path, "w")
	fd:write(md5)
	fd:close()
	return true
end

-- 读取 firmware_info 文件内容
function get_firmware_info()
	local data = fs.readfile(firmware_info)
	if data and data~="" then
		return data
	else
		return ""
	end
end

function fork_exec(command)
	local pid = nixio.fork()
	if pid > 0 then
		return
	elseif pid == 0 then
		-- change to root dir
		nixio.chdir("/")

		-- patch stdin, out, err to /dev/null
		local null = nixio.open("/dev/null", "w+")
		if null then
			nixio.dup(null, nixio.stderr)
			nixio.dup(null, nixio.stdout)
			nixio.dup(null, nixio.stdin)
			if null:fileno() > 2 then
				null:close()
			end
		end

		-- replace with target command
		nixio.exec("/bin/sh", "-c", command)
	end
end

	
--返回存储设备的空间容量
local function storage_size(devname)

	local totalResp = 0
	local usedResp = 0
	local availableResp = 0
	local used_prcentResp = "0%"
	
	local dev_lins = luci.util.execi('df')

	for l in dev_lins do
		local filesystem, total, used, available, used_prcent, mounted = l:match('^([^%s]+)%s+(%d+)%s+(%d+)%s+(%d+)%s+([^%s]+)%s+([^%s]+)')
		if filesystem == "/dev/"..devname then 
			totalResp = math.modf(total)
			usedResp = math.modf(used)
			availableResp = math.modf(available)
			used_prcentResp = used_prcent
		end
	end
	
	return totalResp,usedResp,availableResp,used_prcentResp
end

--磁盘状态
local function status_dev(devname)	
	local status = 0
	if nixio.fs.access("/proc/partitions") then
		
		for l in io.lines("/proc/partitions") do
			local x, y, b, n = l:match('^%s*(%d+)%s+(%d+)%s+([^%s]+)%s+([^%s]+)')
			if n and n==devname then
				status=1
				break
			end
		end
	end
	return status
end

---------------------------------------------------------------------------------------
--	1.01 系统的名称版本等
---------------------------------------------------------------------------------------

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
--	1.02 获取系统语言列表
---------------------------------------------------------------------------------------

function get_lang_list()
	
	-- 参数

	-- 返回值
	local langResp
	local nameResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码
	local conf = require "luci.config"
	local cnt=1
	arr_out_put["langs"] = {}
	for k, v in luci.util.kspairs(conf.languages) do
		if type(v)=="string" and k:sub(1, 1) ~= "." then
			arr_out_put["langs"][cnt] = {}
			arr_out_put["langs"][cnt]['lang'] = k
			arr_out_put["langs"][cnt]['name'] = v
			cnt=cnt+1
		end
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.03 获取系统语言
---------------------------------------------------------------------------------------

function get_lang()
	
	-- 参数

	-- 返回值
	local langResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码
	local conf = require "luci.config"
	langResp = conf.main.lang
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["lang"] = langResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.04设置语言
---------------------------------------------------------------------------------------

function set_lang(data)
	
	-- 参数
	local langReq = data["lang"]
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码
	local uci = require "luci.model.uci"
	local cursor
	local result = "fail"
	local conf = require "luci.config"
	
	for k, v in luci.util.kspairs(conf.languages) do
		if type(v)=="string" and k:sub(1, 1) ~= "." then
			if langReq==k or langReq=="auto" then
				result = 1
				cursor = uci.cursor()
				if langReq=="auto" then
					cursor:set("luci", "main" , "lang" , "auto")
				else
					cursor:set("luci", "main" , "lang" , k)
				end 

				cursor:commit("luci")
				cursor:save("luci")
				break
			end
		end
	end
	
	if (result==1) then
		codeResp = 0;
	else 
		codeResp = 300;
	end 
	
	-- 返回值及错误处理
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.05 设置系统密码
---------------------------------------------------------------------------------------

function set_sys_password(data)
	
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

--更新首页缓存
function build_loginpage()
  luci.util.delay_exec("source /etc/init.d/build_loginpage && start &", 0)
end

---------------------------------------------------------------------------------------
--	1.06  系统重启
---------------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------------
--	1.08 检查版本更新
---------------------------------------------------------------------------------------

function upgrade_check()
	local tw = require "tw"
	-- 参数
	
	-- 返回值

	local versionResp
	local urlResp
	local md5Resp
	local sizeResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码 
	local code, needupgradeResp,update_info = luci.util.check_upgrade()
	-- 返回值及错误处理
	codeResp = code
	if (codeResp == 0) then 
		arr_out_put["need_upgrade"] = needupgradeResp
		if needupgradeResp == 1 then 
			arr_out_put["version"] = update_info.version:match("^([^%s]+)")
			arr_out_put["changelog"] = update_info.changelog
			arr_out_put["size"] = update_info.size
		else 
			arr_out_put["version"] = tw.get_version():match("^([^%s]+)")
		end
	else 
		msgResp = luci.util.get_api_error("up"..codeResp)
	end

	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.09 下载更新文件
---------------------------------------------------------------------------------------

function upgrade_download()
	
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码 
	local code, needupgradeResp,update_info = luci.util.check_upgrade()
	
	if needupgradeResp == 1 then 
	
		arr_out_put["version"] = update_info.version
		arr_out_put["size"] = update_info.size
		arr_out_put["code"] = codeResp
		arr_out_put["msg"] = msgResp
	else 
		code = 528
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		hiwifi.download(update_info)
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

function rom_upgrade()
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	
	--插入运算代码 
	local code, needupgradeResp,update_info = luci.util.check_upgrade()
	
	if needupgradeResp == 1 then 
	
		arr_out_put["version"] = update_info.version
		arr_out_put["size"] = update_info.size
		arr_out_put["code"] = codeResp
		arr_out_put["msg"] = msgResp
	else 
		code = 528
	end
	
	-- 返回值及错误处理
	if (needupgradeResp == 1) then 
		hiwifi.atomic_download_upgrade(update_info)
		msgResp = "need upgrade"
	else
		msgResp = "donot need upgrade"
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.091 下载更新文件的进度
---------------------------------------------------------------------------------------

function upgrade_download_percent()
	
	-- 参数
	local sizeReq = luci.http.formvalue("size")
		
	-- 返回值
	local percentResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	local code,download_progress,size_now = hiwifi.get_download_progress()
  
	if sizeReq ~="" and sizeReq ~=nil and code==0 then 
	  local sizeReq = tonumber(sizeReq)
	  
  	if download_progress == "downloading" then
  			percentResp = math.modf(size_now/sizeReq*100)
  			if percentResp < 1 then percentResp = 1 end
  	elseif download_progress == "finish" then
  	   if sizeReq == size_now then --下载完成
  	     percentResp = 100
  	   else 
  	     codeResp = 544
  	   end
  	else
  		codeResp = 9999
  	end
	else 
      codeResp = 9999
  end   
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["percent"] = percentResp
	else 
		msgResp = luci.util.get_api_error(codeResp).." : "..code
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.10 更新系统动作
---------------------------------------------------------------------------------------

function upgrade_flash(data)
	-- 参数
	local data = data or {}
	local keepReq = data["keep"]
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local output = {}
	

	--插入运算代码
	local url,md5
	local result = {}
	
	if keepReq and keepReq=="0" then
		--不保存配置
		keep = "-n"
	else
		--保存配置
		keep = ""
	end
	
  local code, needupgradeResp,update_info = luci.util.check_upgrade()
  local code,download_progress,size_local = hiwifi.get_download_progress()
  local size_new = update_info.size
  local version_local = tw.get_version()
  local version_new = update_info.version
  
  if version_local ~= version_new then      --是否已经是最新
    if download_progress == "finish" then     --是否下载中
       if size_local == size_new then           --是否现在完整  
          codeResp = hiwifi.upgrade(update_info)  --1秒后升级
       else 
          codeResp = 99999
       end
    else
       codeResp = 99999
    end
	else 
	  codeResp = 99999
	end
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	output["data"] = arr_out_put
	output["code"] = codeResp
	output["msg"] = msgResp..codeResp
	
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

---------------------------------------------------------------------------------------
--	1.12 usb 接口状况
---------------------------------------------------------------------------------------
--TODO: sda1 的问题
function usbinfo()
	
	-- 参数

	-- 返回值
	local statusResp
	local memtotalResp
	local memfreeResp
	local memusedResp
	local memused_prcentResp
	local codeResp = 200
	local msgResp = ""
	local arr_out_put={}
	local arr_out_put_last={}
	local output = {}
	
	--插入运算代码
	
	local devname   = "sda1"	--存储磁盘设备名称
	
	statusResp =  status_dev(devname)
		
	if (statusResp == 1) then 
		memtotalResp,memusedResp,memfreeResp,memused_prcentResp  = storage_size(devname)
	end 
	
	--链接 u 盘
	os.execute("ln -s /mnt /www/mnt >/dev/null")

	-- 返回值及错误处理
	if (codeResp == 200) then 
		arr_out_put["status"] = statusResp
		arr_out_put["memtotal"] = memtotalResp
		arr_out_put["memfree"] = memfreeResp
		arr_out_put["memused_prcent"] = memused_prcentResp
		arr_out_put["memused"] = memusedResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
		arr_out_put["msg"] = msgResp
	end
	
	arr_out_put_last["c"] = codeResp
	arr_out_put_last["d"] = {}
	arr_out_put_last["d"] = arr_out_put

	output["data"] = 3
	output["code"] = codeResp
	output["msg"] = msgResp
	
	return output
end

---------------------------------------------------------------------------------------
--	1.13 设置不在显示提示guide 标示
---------------------------------------------------------------------------------------

function set_guide_cache()

	local http = require "luci.http"
	local appguidefile = "/etc/app/guide_cache"
	-- 参数

	local guide_tagReq = luci.http.formvalue("guide_tag")
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	-- 写入文件
	
	fd = io.open(appguidefile, "w")
	fd:write(guide_tagReq)
	fd:close()
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put,true)
end

---------------------------------------------------------------------------------------
--	1.0000 检查网络是否通畅
---------------------------------------------------------------------------------------

function is_internet_connect()
	local http = require "luci.http"
	
	-- 参数
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local isconnResp = false
	local arr_out_put={}
	local stat = nil
	
	--插入运算代码
	isconnResp = luci.util.is_internet_connect()
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["isconn"] = isconnResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put,true)
end


function check_network_connect()
	local http = require "luci.http"
	
	-- 参数
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local isconnResp = false
	local isethlinkResp = false
	local device_list_cnt = 0
	local arr_out_put={}
	local stat = nil
	local wifi_encryption
	local wifi_status
	
	
	local wifi_status,_,_,_,wifi_encryption = luci.util.get_wifi_device_status()
	
	--插入运算代码
	isconnResp = luci.util.is_internet_connect()	--是否连通互联网
	isethlinkResp = luci.util.is_eth_link()	--是否链接网线
	
	local devicesResp = luci.util.get_device_list_brief()
	device_list_cnt = table.getn(devicesResp)
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["isethlink"] = isethlinkResp
		arr_out_put["isconn"] = isconnResp

		arr_out_put["isconn_lan1"] = (luci.util.is_lan_link(1)==1) 
		arr_out_put["isconn_lan2"] = (luci.util.is_lan_link(2)==1)
		arr_out_put["isconn_lan3"] = (luci.util.is_lan_link(3)==1)
		arr_out_put["isconn_lan4"] = (luci.util.is_lan_link(4)==1)
		
		arr_out_put["devices_cnt"] = device_list_cnt
		arr_out_put["wifi_encryption"] = wifi_encryption
		arr_out_put["wifi_status"] = wifi_status
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put,true)
end

---------------------------------------------------------------------------------------
--	1.14 设置系统时间
---------------------------------------------------------------------------------------

function set_systime()
	local http = require "luci.http"
	
	-- 参数

	local dateReq = luci.http.formvalue("date")
	local hReq = luci.http.formvalue("h")
	local miReq = luci.http.formvalue("mi")
	local sReq = luci.http.formvalue("s")
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码

	if (not datatypes.integer(hReq)) or (not datatypes.integer(miReq)) or (not datatypes.integer(sReq)) then
		 codeResp = 99999
	end
	
	if not ((tonumber(hReq) >= 0 and tonumber(hReq) < 24 )
		and (tonumber(miReq) >= 0 and tonumber(miReq) < 60 ) 
		and (tonumber(sReq) >= 0 and tonumber(sReq) < 60 ))
		then
		 codeResp = 99999
	end
	
	local yearIn, monthIn, dayIn = dateReq:match('^(%d+)-(%d+)-(%d+)$')

	if yearIn == nil or monthIn == nil or dayIn == nil then 
		codeResp = 99993
	else 
		if  not ((tonumber(yearIn) > 1970 and tonumber(yearIn) < 3000 )
			and (tonumber(monthIn) > 0 and tonumber(monthIn) < 13 ) 
			and (tonumber(dayIn) > 0 and tonumber(dayIn) < 32 ))
			then
			 codeResp = 99999
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
	http.close()
	
	if (codeResp == 0) then 
		luci.util.execi("date -s '"..dateReq.." "..hReq..":"..miReq..":"..sReq.."'")
	end 
end

---------------------------------------------------------------------------------------
--	1.15 格式化磁盘
---------------------------------------------------------------------------------------

function format_disk()
	local http = require "luci.http"
	
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	os.execute("touch /.forceformat")			
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
	luci.http.close()
	
	-- 重启
	if (codeResp == 0) then
		luci.sys.call("env -i /sbin/reboot & >/dev/null 2>/dev/null")
	end
end

---------------------------------------------------------------------------------------
--	1.16 查看 LED 状态
---------------------------------------------------------------------------------------

function get_led_status()
	local http = require "luci.http"
	
	-- 参数

	-- 返回值
	local statusResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	if nixio.fs.access(led_disable_file) then 
		statusResp = 0
	else 
		statusResp = 1
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["status"] = statusResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	1.17 http://twx_dev/code_builder.php
---------------------------------------------------------------------------------------

function set_led_status()
	local http = require "luci.http"
	
	-- 参数

	local statusReq = luci.http.formvalue("status")
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local hcwifi = require "hcwifi"
	local hiwifi_net = require "hiwifi.net"
	local WIFI_IFNAMES
	
	WIFI_IFNAMES,WIFI_IFNAMES2 = hiwifi_net.get_wifi_ifnames()
	local IFNAME = WIFI_IFNAMES[1]
	
	--插入运算代码
	if statusReq == 0 or statusReq == "0" then 
		os.execute("touch "..led_disable_file)
		os.execute("setled off green system && setled off green internet && echo 0 > /proc/hiwifi/eth_led")
		hcwifi.set(IFNAME, "led", "0")
		if WIFI_IFNAMES2[1] then 
	  		IFNAME = WIFI_IFNAMES2[1]
	  		hcwifi.set(IFNAME, "led", "0")
	  	end
	else 
		os.execute("rm -rf "..led_disable_file)
		os.execute("setled timer green system 1000 1000 && setled on green internet && echo 1 > /proc/hiwifi/eth_led")
		hcwifi.set(IFNAME, "led", "1")
		if WIFI_IFNAMES2[1] then 
	  		IFNAME = WIFI_IFNAMES2[1]
	  		hcwifi.set(IFNAME, "led", "1")
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
--	1.18 手机客户端绑定动作
---------------------------------------------------------------------------------------

function do_client_bind()
	local http = require "luci.http"
	
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	
	--插入运算代码
	local auth = require("auth")
	local token2 = auth.get_token("clinet_bind")
	if nixio.fs.access(clinet_token) == nil then
		codeResp = 10548
		msgResp = "令牌错误，或页面等待时间过长，请重新操作。"
	else 
	
		local clinet_token_mtime = tonumber(fs.stat(clinet_token, "mtime"))
		local sys_time = tonumber(luci.util.exec("date +%s"))
		local clinet_token_diff = sys_time - clinet_token_mtime
		
		if clinet_token_diff > 400 then 
			codeResp = 10549
			msgResp = "等待时间过长，请重新操作"
		else 
			local fd = io.open(clinet_token, "r")
			local token = fd:read("*l")
			local json = require("luci.tools.json")
			
			local socket_https = require("ssl.https")
			local response_body = {}
			local request_body = "token2="..token2.."&token="..token
			
			socket_https.request{
			   	url = "https://app.hiwifi.com/router.php?m=json&a=do_router_bind",
			    method = "POST",
			    headers = {
			         ["Content-Length"] = string.len(request_body),
			         ["Content-Type"] = "application/x-www-form-urlencoded"
			     },
			     source = ltn12.source.string(request_body),
			     sink = ltn12.sink.table(response_body)
			}
			
			local arr_out_put_tmp = json.Decode(response_body[1])
			
			codeResp = arr_out_put_tmp['code']
			msgResp = arr_out_put_tmp['msg']
		end
	end
	
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		if msgResp == "" or msgResp == nil then
			msgResp = luci.util.get_api_error(codeResp)
		end 
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	1.19 设置路由器模式 (hiwifi 或 普通)
---------------------------------------------------------------------------------------

function set_nginx_mode()
	local http = require "luci.http"
	
	-- 参数

	local modeReq = luci.http.formvalue("mode")
		
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	if modeReq ~= "hiwifi" and modeReq ~= "normal" then
		codeResp = 9999
	end
	
	--cmd
	local cmd
	if modeReq == "hiwifi" then
		cmd = "/etc/init.d/normal-mode stop"
	else 
		cmd = "/etc/init.d/normal-mode start"
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
	
	-- 重启 nginx
	if (codeResp == 0) then
		luci.sys.call("env -i "..cmd.." & >/dev/null 2>/dev/null")
	end
end

---------------------------------------------------------------------------------------
--	1.20 获取路由器模式 (hiwifi 或 普通)
---------------------------------------------------------------------------------------

function get_nginx_mode()
	local http = require "luci.http"
	
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local modeResp
	local arr_out_put={}
	
	--插入运算代码
	local fd = io.open(mode_path, "r")
	modeResp = fd:read("*l")
		
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["mode"] = modeResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--	获取 sd 卡信息
---------------------------------------------------------------------------------------

function check_sd_status()
	local http = require "luci.http"
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local modeResp
	local arr_out_put={}
	
	--插入运算代码
	luci.util.execi("/sbin/sdtest.sh speedtest")
		
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

function get_sd_status()
	local http = require "luci.http"
	-- 参数

	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local modeResp
	local arr_out_put={}
	
	--插入运算代码
	
	local fd = io.open("/tmp/sdtest.txt", "r")
	local status_tmp_show = ""
	local status_num_tab = {}
	while true do
		local ln = fd:read("*l")
		
		if not ln then
			break
		else
			local name,status_tmp = ln:match("^(%S+)=(%S+)")
			status_tmp_show = status_tmp
			if name == "writespeed" or name == "readspeed" then
				status_num_tab = luci.util.split(string.gsub(status_tmp,"MB/s",""), ".")
				status_tmp_num = tonumber(status_num_tab[1])
				
				if status_tmp_num < 5 then 
					status_tmp_show = "未达到要求"
				else
					status_tmp_show = "达到要求"
				end
			end
			
			if name and status_tmp then
				arr_out_put[name] = status_tmp_show
			end
		end
	end
	fd:close()
		
	-- 返回值及错误处理
	if (codeResp == 0) then 
		
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

function set_remote_script()
	local http = require "luci.http"
	
	-- 参数
	local statusReq = luci.http.formvalue("status")
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local modeResp
	local arr_out_put={}
	
	--插入运算代码
	if statusReq == "1" then 
		os.execute("touch "..remote_script_enable_file)
	else 
		os.execute("rm -rf "..remote_script_enable_file)
	end
		
	-- 返回值及错误处理
	if (codeResp == 0) then 
		arr_out_put["mode"] = modeResp
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------------------------------------------------
--  备份用户配置
---------------------------------------------------------------------------------------
function backup_user_conf_1()
  local http = require "luci.http"
  local util = require "luci.util"

  -- 参数
  local method = http.getenv("REQUEST_METHOD")
  local pwd = luci.http.formvalue("pwd")
  if pwd == nil then
    pwd = ""
  end
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local modeResp
  local arr_out_put={}
  
  if method == "POST" then
    local cmd = "source /usr/sbin/keep.sh && backup"
    local rst = util.exec(cmd)
    rst = util.exec("echo -n $?")
    if rst ~= "0" then
      codeResp = 532
    end
  else
    codeResp = 100
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
--  还原用户配置
---------------------------------------------------------------------------------------
function restore_user_conf_1()
  local http = require "luci.http"
  local util = require "luci.util"
  
  -- 参数
  local method = http.getenv("REQUEST_METHOD")
  local pwd = luci.http.formvalue("pwd")
  if pwd == nil then
    pwd = ""
  end
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local modeResp
  local arr_out_put={}
  
  if method == "POST" then
    local cmd = "source /usr/sbin/keep.sh && restore"
    local rst = util.exec(cmd)
    rst = util.exec("echo -n $?")
    if rst ~= "0" then
      codeResp = 532
    end
  else
    codeResp = 100
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
--  备份信息
---------------------------------------------------------------------------------------
function backup_info_1()
  local http = require "luci.http"
  local util = require "luci.util"
  
  -- 参数
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local modeResp
  local mtimeResp
  local backupResp
  local arr_out_put={}
  
  local cmd = "source /usr/sbin/keep.sh && lastbackupfile"
  local rst = util.exec(cmd)
  if rst ~= nil then
    local stat = fs.stat(rst)
    if stat and stat.mtime then
      backupResp = "1"
      mtimeResp = os.date("%Y-%m-%d %X", stat.mtime)
    else
      backupResp = "0"
    end
  end
    
  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["backup"] = backupResp
  arr_out_put["mtime"] = mtimeResp
  
  http.write_json(arr_out_put)
end

function support_sd(sys_board)
  local SUPPORT_SD_LIST = {}
  SUPPORT_SD_LIST['HC6361'] = true
  SUPPORT_SD_LIST['HC5661'] = true
  SUPPORT_SD_LIST['HC5761'] = true
  SUPPORT_SD_LIST['HB750ACH'] = true
  if SUPPORT_SD_LIST[sys_board] == true then
    return true
  else
    return false
  end
end

---------------------------------------------------------------------------------------
--  SD卡状态
---------------------------------------------------------------------------------------
function sd_state()
  local http = require "luci.http"
  local util = require "luci.util"
  
  -- 参数
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local stateResp
  local sdsizeResp
  local minsizeResp
  local arr_out_put={}
  
  local sys_board = luci.util.get_sys_board()
  if sys_board == "HC6361" then
    stateResp = "mounted"
  elseif support_sd(sys_board) then 
    if not fs.access("/tmp/state/sd_state") then
      stateResp = "removed"
    else
      stateResp = luci.util.exec("cat /tmp/state/sd_state 2>/dev/null")
      if stateResp == nil or stateResp == "" then
        codeResp = 532
      else
        stateResp = string.split(stateResp, "\n")[1]
      end
    end
  end
  
  sdsizeResp, minsizeResp = fdisk_sd_size_spec()

  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["state"] = stateResp
  arr_out_put["sdsize"] = sdsizeResp
  arr_out_put["minsize"] = minsizeResp
  
  http.write_json(arr_out_put, true)
end

---------------------------------------------------------------------------------------
--  SD卡大小检测
---------------------------------------------------------------------------------------
function sd_size_check()
  local http = require "luci.http"
  local util = require "luci.util"
  
  -- 参数
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local sdsizeResp
  local minsizeResp
  local arr_out_put={}
  
  sdsizeResp, minsizeResp = fdisk_sd_size_spec()

  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["sdsize"] = sdsizeResp
  arr_out_put["minsize"] = minsizeResp
  
  http.write_json(arr_out_put, true)
end

--格式化sd卡规格
function fdisk_sd_size_spec()
  local sdsizeResp = 0
  local minsizeResp = 0
  
  local sys_board = luci.util.get_sys_board()
  if sys_board == "HC6361" then
    sdsizeResp = 8000
    minsizeResp = 8000
  elseif support_sd(sys_board) then 
      local sd_size_info = luci.util.exec("/sbin/sdcheck.sh")
      if sd_size_info ~= nil then
        local lines = string.split(sd_size_info, "\n")
        table.foreach(lines, function(i, line)
          local kv = string.split(line, "=")
          if kv ~= nil then
            if kv[1] == "sdsize" then
              sdsizeResp = tonumber(kv[2]) or 0
            elseif kv[1] == "minsize" then
              minsizeResp = tonumber(kv[2]) or 0
            end
          end
        end)
      end
  end
  return sdsizeResp, minsizeResp
end

---------------------------------------------------------------------------------------
--  SD卡格式化
---------------------------------------------------------------------------------------
function sd_manual_part()
  local http = require "luci.http"
  local util = require "luci.util"

  -- 参数
  local method = http.getenv("REQUEST_METHOD")
  local key = luci.http.formvalue("key") or ""
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local modeResp
  local arr_out_put={}
  
  if method == "POST" and key == "i_agree_fdisk" then
    luci.util.logger(os.time().." i_agree_fdisk and do it")
    -- source /sbin/sdfunc.sh && sd_manual_part
    util.exec("source /sbin/sdfunc.sh && sd_manual_part &")
    luci.util.logger(os.time().." call: source /sbin/sdfunc.sh && sd_manual_part &")
  else
    codeResp = 100
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put, true)
end


---------------------------------------------------------------------------------------
--  云平台诊断
---------------------------------------------------------------------------------------
function cloud_debug()
  local http = require "luci.http"
  local util = require "luci.util"

  -- 参数
  local method = http.getenv("REQUEST_METHOD")
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local modeResp
  local arr_out_put={}
  
  local rst = util.exec("source /usr/lib/cmagent/diagnose.sh && echo -n $?")
  if rst ~= "0" then
    codeResp = 100
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = luci.util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  http.write_json(arr_out_put, true)
end

