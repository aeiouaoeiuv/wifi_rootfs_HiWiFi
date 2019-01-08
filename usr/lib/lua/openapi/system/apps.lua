-- Copyright (c) 2014 HiWiFi Co., Ltd.
-- Author: Longfei Qiao <longfei.qiao@hiwfii.tw>

local os = os
local fs = require("nixio.fs")
local json = require('hiwifi.json')

module("openapi.system.apps", package.seeall)

function refresh()
  os.execute("/etc/init.d/market restart")

  output["code"] = "0"
  output["msg"] = "market reload success"
  output["data"] = ""

  return output
end

function get_info(data)
  -- 参数
  local app_name = ""
  if type(data) == "table" then
    app_name = data["app_name"]
  end

  --输出
  local output = {}

  if app_name == "" or app_name == nil then
    output["code"] = "1"
    output["data"] = ""
    output["msg"] = "data type error"
	return output
  end

  local path = "/etc/market/"..app_name..".info"
  local app_info = ""
  if fs.stat(path) == nil then
    output["code"] = "0"
    output["msg"] = "app not installed"
    output["data"] = ""
  else
    app_info = fs.readfile(path)

    output["data"] = json.decode(app_info)
    output["code"] = "0"
    output["msg"] = ""
  end 

  return output
end
