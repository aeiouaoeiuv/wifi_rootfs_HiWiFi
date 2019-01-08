-- Copyright (c) 2014 Elite Co., Ltd.
-- Author: Wangchao <chao.wang@hiwifi.tw>

local os = os

local cmagent = require "hiwifi.cmagent"
local io = require "io"

-- Parse message.
local data = cmagent.parse_data()
local command
local return_code
local pp

if data.cmd == "setCloudkey" then
  if data.cloudkey ~= nil or data.cloudkey ~= "" then
    command = '. "/etc/app/applogin.script" ; putkey "'..data.cloudkey..'"'
    pp  = io.popen(command)
    pp:close()
    return_code = 0
  else
    return_code = 102
  end
else
  return_code = 101
end

os.exit(return_code)