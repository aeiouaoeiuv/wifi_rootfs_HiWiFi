-- this is mobileapp base
-- Copyright (c) 2013 Geek-Geek Co., Ltd.
-- Author: wanchao <chao.wang@hiwifi.tw>
local auth = require("auth")
local util = require("hiwifi.util")

module "hiwifi.mobileapp.base"

local pairs, table = pairs, table
local MOBLIE_APP_SERVER_HOST = "https://m.hiwifi.com/"
local MOBLIE_APP_API_PATH = "api/"
local MOBILE_APP_URL = MOBLIE_APP_SERVER_HOST..MOBLIE_APP_API_PATH

-- act_init
--@return result_json (act_id, ...) create from mobile app server , before this action, need get a router router_token for this
function act_init(cmdtype)
	local code,token,result_json
	token,code = get_router_token()
	if token == nil or token =="" then
	    return false,code
	else 
		local request_body={
			token=token,
			cmdtype=cmdtype
		}
		local result_json,code = mobile_app_curl("Router/doActInitByToken",request_body)
		return result_json,code
	end
end

-- create mobie app request url and do curl
function mobile_app_curl(action,request_body)
	local response_body,code = util.https_curl_post(MOBILE_APP_URL..action, request_body)
	return response_body,code
end

-- 获取路由器 router_token
function get_router_token()
	local router_token
	local code=0
	
	local router_token,servercode = auth.get_token("mobile_app")
	if router_token == nil or router_token == "" then
		code = servercode
	end
	return router_token,code
end
