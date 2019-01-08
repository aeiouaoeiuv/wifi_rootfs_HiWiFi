-- speed test function
-- Copyright (c) 2013 Geek-Geek Co., Ltd.
-- Author: wanchao <chao.wang@hiwifi.tw>
local auth = require("auth")
local util = require("hiwifi.util")
local json = require("hiwifi.json")
local base = require("hiwifi.mobileapp.base")
local pairs, table ,os ,print = pairs, table, os ,print

module "hiwifi.mobileapp.st"

local DO_ST_SCRIPT = "/sbin/speedtest.sh"

-- do st function
--@return true or false
function do_st(actid_last)
	local result_json,code = base.act_init("speedtest")
	local actid
	local is_debug = 0
	
	if actid_last == nil or actid_last == "" then
		--TODO 脚本不支持  actid_last =  "" or actid_last == 0 所以目前用 actid_last  = "no" 代替
		actid_last = 0
	end
	
	local data_tmp = json.decode(result_json)
	data_tmp['actid_last'] = actid_last
	result_json = json.encode(data_tmp)
	
	print(result_json)
		
	os.execute(DO_ST_SCRIPT.." '"..result_json.."' "..is_debug.." &> /dev/null  &")
	data = json.decode(result_json)
	return data['actid'],code
end