
local os, type, string = os, type, string
local openapi_utils = require("openapi.utils.utils")
local util = require("luci.util")
local DEBUG = true

module("openapi.apps.appengine",package.seeall)

function unsign_config_reload(data)
  local output = {}
  local cmd = ""
  openapi_utils.debug(DEBUG,"=============config_reload==============")
  openapi_utils.debug(DEBUG,data)

  openapi_utils.debug(data, DEBUG)
  if type(data) ~= "table" then
  	cmd = "haetool config-reload 2>/dev/null"
  else
    local service = data.service or ""
    local services = ""
    if type(service) == "table" then
  	  for k,v in pairs(service) do
        services = services.." "..v
      end
    end
    cmd = "haetool config-reload "..services .. " 2>/dev/null"
  end

  local ret = util.exec(cmd)
  if string.match(ret,"success") ~= nil then
    return openapi_utils.ret_output("0", "market reload success", "")
  else
    return openapi_utils.ret_output("10126", "config_reload failed", "")
  end
end
