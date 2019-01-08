local json = require("hiwifi.json")
local util = require("luci.util")
local fs = require "nixio.fs"
local io, pairs, table ,os ,print, string, type, tonumber, tostring = io, pairs, table, os ,print, string, type, tonumber, tostring
local utils  = require("openapi.utils.utils")
local authz = require("openapi.authz")

local uci = require "luci.model.uci"
local x  = uci.cursor()

local OPENAPI_CONF_DIR = "/etc/openapi.d"
local DEBUG = true

module("openapi.callapi", package.seeall)

function callapi(body, sign)
  utils.debug(DEBUG, "=========================callapi in======================\n")
  utils.debug(DEBUG, body)
  local output = {}

  local body_t = json.decode(body)
  local app_user = get_username_by_appid(body_t.app_id)

  --auth permission
  local function safe_auth()
    output = authz.auth(body, sign)
  end
  if app_user == "" then
    if pcall(safe_auth) then
    else
      return utils.ret_output("100003", "权限认证失败", "")
    end

    if output["code"] ~= "0" then
      return output
    end
  end

  --call method
  local function safe_call()
    output = call(body, app_user)
  end
  if pcall(safe_call) then
  else
    return utils.ret_output("100001", "系统内部错误", "")
  end
  return output
end

function call(body, app_user)
  utils.debug(DEBUG, "=========================call in======================\n")
  utils.debug(DEBUG, body)

  local body_t = json.decode(body)
  local output = {}
  local method = parse_method(body_t.method)

  if method["module"] == nil or method["path"] == nil or method["func"] == nil then
    return utils.ret_output("100002", "方法解析失败", "")
  end

  if app_user ~= "" then
    local setuid = require("setuid")
    local uci = require("luci.model.uci")
    local x  = uci.cursor()
    local approot = x:get("appengine", "global", "develroot")
    setuid.chroot(approot)
    
    setuid.setuser(app_user)
    _G.package.cpath = "/apps/"..app_user.."/lib/lua/?.so;" .. _G.package.cpath 
    _G.package.path = "/apps/"..app_user.."/lib/lua/?.lua;" .. _G.package.path 
  end

  local apis = require(method["path"])
  local f = apis[method["func"]]
  if type(f) ~= "function" then
    return utils.ret_output("100004", "api没找到", "")
  end

  local env = body_t

  output = f(body_t.data, env)
  utils.debug(DEBUG, output)
  utils.debug(DEBUG, "=========================call out======================\n")
  return output
end

function get_username_by_appid(app_id)
  local uci = require "luci.model.uci"
  local x  = uci.cursor()
  local devel_root = x:get("appengine","global","develroot")
  if type(devel_root) ~= "string" or devel_root == "" then
    return ""
  end
  local profile = devel_root .. "/etc/market.profile/id:" .. app_id

  if fs.access(profile) == nil then
    return ""
  end

  local app_info = fs.readfile(profile)
  local app_info_t = util.split(app_info,",")
  local app_name = app_info_t[1]
  local user_name = app_info_t[2]

  return user_name or ""
end

function parse_method(method)
  local output = {}

  local method_t = util.split(method, ".")
  local len = table.getn(method_t)

  output["module"] = method_t[len - 1]
  output["func"] = method_t[len]
  output["path"] = "openapi."..string.gsub(method, "."..output["func"], "")

  return output
end

function gen_client_secret()
  local cmd = "cat /proc/sys/kernel/random/uuid | md5sum | awk {'print $1'}"
  local secret = util.exec(cmd)
  secret = string.gsub(secret, "\n", "")
  return secret
end

function bind(body)
  utils.debug(DEBUG, "=========================bind in======================\n")
  utils.debug(DEBUG, body)
  local output = {}
  local body_t = json.decode(body)

  if body_t.app_id == nil or body_t.app_id == "" or body_t.client_id == nil or body_t.client_id == "" then
    return utils.ret_output("100016", "app_id或者client_id不合法", "")
  end

  local APP_CONF_DIR = OPENAPI_CONF_DIR.."/"..body_t.app_id
  local ClIENT_CONF_DIR = APP_CONF_DIR.."/"..body_t.client_id
  local CLIENT_PERMISSIONS_FILE = ClIENT_CONF_DIR.."/permissions"
  local CLIENT_SECRET_FILE = ClIENT_CONF_DIR.."/client_secret"

  if type(body_t.data) ~= "table" or body_t.data.client_secret == "" or body_t.data.client_secret == nil then
    return utils.ret_output("100006", "客户端密匙不合法", "")
  end

  if fs.access(APP_CONF_DIR) == nil then
    return utils.ret_output("100005", "插件未安装或者未授权", "")
  end

  --客户端已被绑定
  if fs.access(ClIENT_CONF_DIR) then
    --get client_key
    local client_secret_file = fs.readfile(CLIENT_SECRET_FILE)
    local client_secret = util.split(client_secret_file,"\n")[1]
    output.client_secret = client_secret

    --get client_permissions
    output.permissions = {}
    local i = 1
    local fd = io.open(CLIENT_PERMISSIONS_FILE, "r")
    for line in fd:lines() do
        output.permissions[i] = line
        i = i + 1
    end
    fd:close()

    return utils.ret_output("100007", "客户端已被绑定", output)
  end

  --check if permissions are in cloud permissions 
  if authz.auth_bind_permission(body_t) == false then
    return utils.ret_output("100008", "客户端申请权限超出允许范围", output)
  end

  --set permission list
  fs.mkdirr(ClIENT_CONF_DIR)
  fs.writefile(CLIENT_PERMISSIONS_FILE, table.concat(body_t.permissions, "\n"))

  --set app_secret
  local data = {}
  --data.client_secret = gen_client_secret()
  data.client_secret = body_t.data.client_secret
  fs.writefile(CLIENT_SECRET_FILE, data.client_secret)
  return utils.ret_output("0", "绑定成功", data)
end

function unbind(body)
  local output = {}
  local body_t = json.decode(body)

  local APP_CONF_DIR = OPENAPI_CONF_DIR.."/"..body_t.app_id
  local ClIENT_CONF_DIR = APP_CONF_DIR.."/"..body_t.client_id

  if fs.access(ClIENT_CONF_DIR) == nil then
	return utils.ret_output("100008", "客户端绑定关系未找到", "")
  else
    os.execute("rm -rf "..ClIENT_CONF_DIR)
	return utils.ret_output("0", "解除绑定成功", "")
  end

  return output
end

