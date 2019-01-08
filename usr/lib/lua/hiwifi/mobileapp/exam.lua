-- speed test function
-- Copyright (c) 2013 Geek-Geek Co., Ltd.
-- Author: wanchao <chao.wang@hiwifi.tw>
local auth = require("auth")
local util = require("hiwifi.util")
local util_l = require("luci.util")
local json = require("hiwifi.json")
local base = require("hiwifi.mobileapp.base")
local pairs, table ,os = pairs, table, os

module "hiwifi.mobileapp.exam"

-- do st function
--@return true or false
function do_exam()
	local result_json,code = base.act_init("exam")
	local actid

	data_json = result_json
	data = json.decode(result_json)
	return data,code
end