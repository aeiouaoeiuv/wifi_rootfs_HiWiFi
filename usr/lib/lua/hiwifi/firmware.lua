-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local os, io, string = os, io, string
local auth = require "auth"
local conf = require "hiwifi.conf"
local json = require "hiwifi.json"
local util = require "hiwifi.util"
local digest = require "hiwifi.digest"
local protocol = require "luci.http.protocol"
local lock = require "hiwifi.lock"
local nixio = require "nixio"
local fs = require "nixio.fs"
local tw = require "tw"
local type = type



module "hiwifi.firmware"

ERROR_CODE = {
  E_OKAY = 0,
  E_VERSION = 1,        --Version dismatched.
  E_HARDWARE = 2,
  E_MD5 = 3,            --MD5 sum dismatched.
  E_HTTP = 4,           --Something went wrong during downloading firmware, refers to http(s) errors.
  E_BUSY = 5,           --Firmware being used.
  E_SYSTEM = 6,          
  E_NOFW = 7,           --No local firmware found.
  E_METADATA = 8,       --Illegal metadata queried.
}

local e = ERROR_CODE

ERROR_STRING = {
  [e.E_OKAY] = "Success",
  [e.E_VERSION] = "Version dismatched",
  [e.E_HARDWARE] = "Hardware unavailable",
  [e.E_MD5] = "Md5sum dismatched",
  [e.E_HTTP] = "HTTP error detected",
  [e.E_BUSY] = "Firmware is being used",
  [e.E_SYSTEM] = "System fault",
  [e.E_NOFW] = "No local firmware found",
  [e.E_METADATA] = "Illegal metadata queried from server",
}


local CACHE_DIRECTORY = conf.firmware_path
local CACHED_FIRMWARE_FILE = CACHE_DIRECTORY .. "/cached_firmware"
local CACHED_FIRMWARE_INFO_FILE = CACHE_DIRECTORY .. "/cached_firmware_info"


local function do_set_cached_info(info)
  local json_info = json.encode(info)
  fs.writefile(CACHED_FIRMWARE_INFO_FILE, json_info)
end


local function do_get_cached_info()
  if not fs.access(CACHED_FIRMWARE_INFO_FILE, "f") then
    return e.E_NOFW, nil
  end
  local str = fs.readfile(CACHED_FIRMWARE_INFO_FILE)
  local ret = json.decode(str)
  if ret == nil then
    return e.E_METADATA, nil 
  end
  return e.E_OKAY, ret 
end


local function get_cached_version()
  local c, r = do_get_cached_info()
  if c ~= e.E_OKAY then
    return nil
  end
  return r.version
end


--- Get metadata of the latest firmware to be updated to.
-- @param from a string identifier of different callers
-- @return metadata of the latest firmware in a table or nil if no update
-- @return reason on failing to find an update
-- @return detail message on the failure
local function do_get_update_info(from)
  local url = "https://cloud.hiwifi.com/api/latest_rom?"
  local query_string = protocol.urlencode_params({
    model = tw.get_model(),
    token = auth.get_token('firmware'),
    id = tw.get_mac(),
    from = from,
    current = tw.get_version(),
    cached = get_cached_version()
    })
  local content, res, code = util.download_to_string(url .. query_string)
  if res == nil then
    return e.E_HTTP, code
  end
  local firmware = json.decode(content)
  if firmware == nil then
    return e.E_METADATA, content
  end
  return e.E_OKAY, firmware
end

--- Notifies Nginx that a cached firmware update is ready.
-- @return 0 if succeed to notify Nginx, other numbers if failed
function enable_notification()
  local ok = os.execute("/usr/bin/wget -q -O - 'http://tw-vars:81/set?key=upgrade&value=1'")
  return ok / 256
end

--- Downloads from a URL to a local file and checks the md5 checksum.
--- This function will block until download finishes or timeout.
--- If md5 verification fails, the downloaded file is removed.
--@param param a table used in luasocket, or just url string
--@param file local file name with full path
--@param md5 the expected md5 checksum of local file
--@return E_OKAY on success, others on failure.
local function download_with_md5_verify(param, file, md5)
  local ret = util.download_to_file(param, file)
  if type(ret) ~= "number" or ret ~= 200 then
    return e.E_HTTP
  end

  local actual_md5 = digest.md5file(file)
  if actual_md5 ~= md5 then
    return e.E_MD5
  end
  return e.E_OKAY
end


local function local_firmware_verify(md5, version)

  if not fs.access(CACHED_FIRMWARE_FILE, "f") then
    return e.E_NOFW
  end

  local ret, cached_info = do_get_cached_info()
  if ret ~= e.E_OKAY then
    return ret
  end

  if cached_info.version ~= version then
    return e.E_VERSION
  end

  if cached_info.md5 ~= md5 or md5 ~= digest.md5file(CACHED_FIRMWARE_FILE) then
    return e.E_MD5
  end

  return e.E_OKAY
end

local function clean_cache()
  fs.remove(CACHED_FIRMWARE_FILE)
  fs.remove(CACHED_FIRMWARE_INFO_FILE)
end


local function hardware_verify(rom_path)
  if (0 ~= os.execute(
    ". /etc/functions.sh; " ..
    "include /lib/upgrade; " ..
    "platform_check_image ".. rom_path .." &>/dev/null"
    )) then
    return e.E_HARDWARE
  end
  return e.E_OKAY
end


local function do_download(fw)
  fs.mkdir(CACHE_DIRECTORY)
  ret = local_firmware_verify(fw.md5, fw.version)
  if ret == e.E_OKAY then
    return ret
  end
  clean_cache()
  ret = download_with_md5_verify(fw.url, CACHED_FIRMWARE_FILE, fw.md5)
  if ret ~= e.E_OKAY then
    clean_cache()
  else
    do_set_cached_info(fw)
  end
  return ret
end


local function do_upgrade(fw, cmd)
  if fw.version == tw.get_version() then
    return e.E_OKAY
  end
  local ret = local_firmware_verify(fw.md5, fw.version)
  if ret ~= e.E_OKAY then
    return ret
  end
  ret = hardware_verify(CACHED_FIRMWARE_FILE)
  if ret ~= e.E_OKAY then
    return ret
  end
  os.execute(cmd)
  return e.E_OKAY
end


function get_update_info(from)
  return do_get_update_info(from)
end


function download(fw)
  local lk = lock.trylock("firmware")
  if lk == nil then
    return e.E_BUSY
  end
  local ret = do_download(fw)
  lock.unlock(lk)
  return ret
end

function get_cached_info()
  return do_get_cached_info()
end

function upgrade(fw)
  local lk = lock.trylock("firmware")
  if lk == nil then
    return e.E_BUSY
  end
  local cmd = "/usr/sbin/hwf-at 1 '/sbin/sysupgrade " .. CACHED_FIRMWARE_FILE .. "'"
  local ret = do_upgrade(fw, cmd)
  lock.unlock(lk)
  return ret
end

function wait_download(fw)
  --Fall to sleep until the lock is released.
  local lk = lock.flock("firmware")
  local ret = do_download(fw)
  lock.unlock(lk)
  return ret
end

function wait_upgrade(fw)
  local lk = lock.flock("firmware")
  local cmd = "/sbin/sysupgrade " .. CACHED_FIRMWARE_FILE .. " &"
  local ret = do_upgrade(fw, cmd)
  lock.unlock(lk)
  return ret
end

function get_download_progress()
  local cur_size = fs.stat(CACHED_FIRMWARE_FILE, "size")
  if lock.test_lock("firmware") == "locked" then
    return e.E_OKAY, "downloading", cur_size
  else
    if cur_size ~= nil then
      return e.E_OKAY, "finish", cur_size
    else
      return e.E_NOFW, nil, nil
    end
  end
end


function atomic_download_upgrade(fw)
  local up_lk = lock.trylock("upgrade")
  if up_lk == nil then
    return e.E_BUSY
  end
  local fw_lk = lock.flock("firmware")
  local ret = do_download(fw)
  if ret ~= e.E_OKAY then
    lock.unlock(fw_lk)
    lock.unlock(up_lk)
    return ret
  end
  local cmd = "/sbin/sysupgrade " .. CACHED_FIRMWARE_FILE .. " &"
  ret = do_upgrade(fw, cmd)
  lock.unlock(fw_lk)
  lock.unlock(up_lk)
  return ret
end

function get_download_path()
  return CACHED_FIRMWARE_FILE
end

function get_error_string(err)
  return ERROR_STRING[err]
end
