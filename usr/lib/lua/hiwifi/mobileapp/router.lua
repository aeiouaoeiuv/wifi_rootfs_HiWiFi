-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local os, string, table = os, string, table
local auth = require "auth"
local json = require "hiwifi.json"
local strings = require "hiwifi.strings"
local util = require "hiwifi.util"
local ltn12 = require "ltn12"
local https = require "ssl.https"
local tw = require "tw"

local util2 = require "luci.util"

module "hiwifi.mobileapp.router"

--- Reports current installed apps to server.
--@return true if successfully reported, otherwise false
function set_cloudkey()
  local body="mac="..tw.get_mac().."&router_token="..auth.get_token("mobile_app")
  local resp = util.download_to_string({
    url = "http://m.hiwifi.com/api/Router/getCloudkey",
    source = ltn12.source.string(body),
    method = 'POST',
    headers = {
      ["Content-Length"] = string.len(body),
      ["Content-Type"] = "application/x-www-form-urlencoded"
    }
  })
  local res_data = json.decode(resp)
  return(res_data['code'] == "0" or  res_data['code'] == 0)
end