-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local os, string, table = os, string, table
local auth = require "auth"
local conf = require "hiwifi.conf"
local json = require "hiwifi.json"
local lock = require "hiwifi.lock"
local strings = require "hiwifi.strings"
local util = require "hiwifi.util"
local ltn12 = require "ltn12"
local fs = require "nixio.fs"
local https = require "ssl.https"
local tw = require "tw"

module "hiwifi.market"

-- Directory to save info of installed apps.
-- It must NOT be on USB disk, otherwise the info stays while all nginx confs
-- are gone after reset.
local PATH = "/etc/market"

local function get_app_info(app_id)
  return PATH .. "/" .. app_id .. ".info"
end

local function get_app_script(app_id)
  return PATH .. "/" .. app_id .. ".script"
end

local function get_app_metadata(file)
  local content = fs.readfile(file)
  local result = json.decode(content)
  if result == nil then
    return nil
  end
  local app = {
    ename = result['ename'],
    version = result['version']
  }
  return app
end

local function do_uninstall(app_id)
  local script = get_app_script(app_id)
  local file_stat = fs.stat(script)
  if file_stat and file_stat.type == "reg" then
    os.execute(". " .. script .. " && uninstall")
  end
  fs.remove(script)
  fs.remove(get_app_info(app_id))
end

--- Lists all installed apps.
--@return a list
function list()
  local files = fs.dir(PATH)
  local apps = {}
  if files == nil then
    return apps
  end
  while true do
    local file = files()
    if file == nil then
      return apps
    end
    if string.gmatch(file, ".info$") then
      local app = get_app_metadata(PATH .. "/" .. file)
      if app ~= nil then
        table.insert(apps, app)
      end
    end
  end
end

--- Calls predefined function in the script of the app.
--@param app_id the installed app
--@param func_name name of the function to be called
--@return return code
function call_function(app_id, func_name)
  local script = get_app_script(app_id)
  local filtered_name = string.gsub(func_name, "[^0-9a-zA-Z_]", "")
  return os.execute(string.format(
      "/usr/lib/market/call_func %s %s", script, filtered_name)) / 256
end

--- Reports current installed apps to server.
--@return true if successfully reported, otherwise false
function report()
  local apps = list()
  local body = json.encode({
    devid = tw.get_mac(),
    token = auth.get_token("market"),
    model = tw.get_model(),
    version = tw.get_version(),
    apps = apps
  })
  local resp = util.download_to_string({
    url = "https://mp.hiwifi.com/router.php?m=cloud&a=resetapp",
    source = ltn12.source.string(body),
    method = 'POST',
    headers = {
      ["Content-Length"] = #body
    }
  })
  return (strings.trim(resp) == "HIWIFI MARKET: OK")
end

--- Installs a specified app.
--@param data which contains url and md5 to download the specified app
--@return 0 if succeed, other values if failed
function install(data)
  local PKG_FILE = "_conf.tgz"
  local METADATA_FILE = "app.json"
  local SCRIPT_FILE = "script"
  --Add lock
  lock.lock("market")
  local is_succeed = util.download_to_file_with_md5_checking(data.url, PKG_FILE, data.md5)
  if not is_succeed then
    return 1
  end
  if 0 ~= os.execute("tar xzf " .. PKG_FILE) then
    return 2
  end
  fs.remove(PKG_FILE)
  local meta = json.decode(fs.readfile(METADATA_FILE))
  if meta == nil then
    return 3
  end
  local app_id = meta['ename']
  if app_id == nil then
    return 3
  end
  do_uninstall(app_id)
  fs.mkdirr(PATH)
  local install_result = os.execute(". " .. SCRIPT_FILE .. " && install")
  if install_result ~= 0 then
    do_uninstall(app_id) -- Rollback
    lock.unlock("market")
    return install_result / 256
  end
  fs.copy(SCRIPT_FILE, get_app_script(app_id))
  fs.copy(METADATA_FILE, get_app_info(app_id))
  lock.unlock("market")
  return 0
end

--- Uninstalls a specified app.
--@param app_id ID of the specified app
--@return 0 if succeed, other values if failed
function uninstall(app_id)
  if not app_id then
    return 2
  end
  lock.lock("market")
  do_uninstall(app_id)
  lock.unlock("market")
  return 0
end
