local json = require("hiwifi.json")
local util = require("luci.util")
local fs = require "nixio.fs"
local io, pairs, table ,os ,print, string, type, tonumber, tostring = io, pairs, table, os ,print, string, type, tonumber, tostring
local utils  = require("openapi.utils.utils")

local OPENAPI_CONF_DIR = "/etc/openapi.d"
local DEBUG = true

module "openapi.authz"

function auth_body_type(body_t)
  if type(body_t) ~= "table" or body_t.method == nil or body_t.method == "" then
    return false
  end
  return true
end

function auth(body, sign)
  utils.debug(DEBUG, "=========================auth in======================\n")
  utils.debug(DEBUG, body)
  local output = {}
  local body_t = json.decode(body)

  if auth_body_type(body_t) ~= true then
    return utils.ret_output("100009","调用方法数据格式错误","")
  end

  if is_nosign(body_t) == true then
    return utils.ret_output("0","无需认证的接口","")
  end

  output = auth_sign(body, sign)
  if output["code"] ~= "0" then
    return output
  end

  output = auth_client_permission(body_t)
  if output["code"] ~= "0" then
    return output
  end

  return utils.ret_output("0","认证成功","")
end

function is_nosign(body_t)
  local method = body_t.method
  if method == nil or method == "" then
    return false
  end
  local str = string.match(method, "unsign")
  if str == "unsign" then
    return true
  else
    return false
  end
end

function auth_sign(body, sign)
  local body_t = json.decode(body)

  if body_t.client_id == nil or body_t.client_id == "" then
    return utils.ret_output("0","auth success","")
  end

  local APP_CONF_DIR = OPENAPI_CONF_DIR.."/"..body_t.app_id
  local ClIENT_CONF_DIR = APP_CONF_DIR.."/"..body_t.client_id
  local CLIENT_SECRET_FILE = ClIENT_CONF_DIR.."/client_secret"

  if fs.access(ClIENT_CONF_DIR) == nil then
	return utils.ret_output("100012", "客户端未绑定", "")
  end

  if sign == nil or sign == "" then
    return utils.ret_output("0","auth success","")
  end

  local client_secret_file = fs.readfile(CLIENT_SECRET_FILE)
  local client_secret = util.split(client_secret_file,"\n")[1]
  if client_secret == "" or client_secret == nil then
    return utils.ret_output("100013", "客户端密匙丢失", "")
  end

  local action = "call"
  local cmd = "echo -n '"..action..body..client_secret.."' |md5sum |awk '{printf $1}'"
  local key = util.exec(cmd)
  if string.lower(key) == string.lower(sign) then
    return utils.ret_output("0", "认证成功", "")
  end
  return utils.ret_output("100014", "校验失败", "")
end

function auth_client_permission(body_t)
  local client_id = body_t.client_id
  if client_id == nil or client_id == "" then
    client_id = "cloud"
  end

  local APP_CONF_DIR = OPENAPI_CONF_DIR.."/"..body_t.app_id
  local ClIENT_CONF_DIR = APP_CONF_DIR.."/"..client_id
  local CLIENT_PERMISSIONS_FILE = ClIENT_CONF_DIR.."/permissions"

  local fd = io.open(CLIENT_PERMISSIONS_FILE, "r")
  if fd == nil or fd == "" then
    return utils.ret_output("100010", "权限列表丢失","")
  end

  local perm = 0
  for line in fd:lines() do
    local len = string.len(line)
    if string.sub(line, len - 1, len) == ".*" then
      if string.sub(line, 1, len - 1) == string.sub(body_t.method, 1, len -1) then
        perm = 1
      end
    elseif line == body_t.method then 
      perm = 1
    end
  end
  
  fd:close()
  if perm == 1 then
    return utils.ret_output("0","","")
  end
  return utils.ret_output("100015", "无权限", "")
end

function auth_bind_permission(body_t)
  local APP_CONF_DIR = OPENAPI_CONF_DIR.."/"..body_t.app_id
  local ClIENT_CONF_DIR = APP_CONF_DIR.."/".."cloud"
  local CLIENT_PERMISSIONS_FILE = ClIENT_CONF_DIR.."/permissions"
  local permissions = body_t.permissions
  local cloud_permissions = {}

  local fd = io.open(CLIENT_PERMISSIONS_FILE, "r")
  if fd == nil or fd == "" then
    return false
  end

  local i = 1
  for line in fd:lines() do
    cloud_permissions[i] = line
    i = i + 1
  end
  fd:close()

  for _ , method in pairs(permissions) do
    utils.debug(DEBUG,"client method:"..method)
    local exist = 0
    for _, cloud_method in pairs(cloud_permissions) do
      local method = method
      utils.debug(DEBUG,"cloud method:"..cloud_method)
      local len = string.len(cloud_method)
      if string.sub(cloud_method, len - 1, len) == ".*" then
        if string.sub(cloud_method, 1, len - 1) == string.sub(method, 1, len -1) then
          exist = 1
        end
      elseif cloud_method == method then 
        exist = 1
      end
    end
    utils.debug(DEBUG,"exist: "..exist.."\n")

    if exist == 0 then
      return false
    end 
  end
  
  return true
end
