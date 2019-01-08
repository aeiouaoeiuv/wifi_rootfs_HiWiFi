-- Copyright (c) 2013 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local os = os
local cmagent = require "hiwifi.cmagent"
local firmware = require "hiwifi.firmware"
local tw = require "tw"

local e = firmware.ERROR_CODE

--- Downloads the latest firmware to cache and notify the user.
--@param latest_firmware the firmware to be downloaded
--@return 0 if success
local function cache_and_notify(latest_firmware)
  local error_code = firmware.download(latest_firmware)
  if error_code ~= e.E_OKAY then
    return error_code
  end
  return firmware.enable_notification()
end

local function need_upgrade(fw)
  if tw.get_version() ~= fw.version then
    return true
  end
  return false
end

local data = cmagent.parse_data()

local ret, latest_firmware = firmware.get_update_info(data.from)
if ret ~= e.E_OKAY then
  print(ret)
  print(latest_firmware)
  os.exit(102)
end

local return_code
if data.cmd == "upgrade" then
  if need_upgrade(latest_firmware) == true then
    return_code = firmware.atomic_download_upgrade(latest_firmware)
  else
    return_code = e.E_OKAY
  end
elseif data.cmd == "notify" then
  return_code = cache_and_notify(latest_firmware)
elseif data.cmd == "download" then
  return_code = firmware.download(latest_firmware)
else
  return_code = 101
end
os.exit(return_code)
