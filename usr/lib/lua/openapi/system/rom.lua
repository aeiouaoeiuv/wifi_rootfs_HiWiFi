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

module("openapi.system.rom", package.seeall)

---------------------------------------------------------------------------------------
-- 检查版本更新
---------------------------------------------------------------------------------------
function check()
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

function upgrade()
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
