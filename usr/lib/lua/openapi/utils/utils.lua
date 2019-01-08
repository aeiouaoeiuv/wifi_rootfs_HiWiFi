local json = require("hiwifi.json")
local util = require("luci.util")
local fs = require "nixio.fs"
local io, pairs, table ,os ,print, string, type, tonumber, tostring = io, pairs, table, os ,print, string, type, tonumber, tostring

module("openapi.utils.utils", package.seeall)

function debug(switch, msg)
  if switch == true then
    util.logger(os.date())
    util.logger(msg)
  end
end

function ret_output(code,msg,data)
  local output = {}

  local code = code or "1"
  local msg = msg or ""
  local data = data or ""

  output["code"] = code
  output["msg"] = msg
  output["data"] = data

  return output
end

