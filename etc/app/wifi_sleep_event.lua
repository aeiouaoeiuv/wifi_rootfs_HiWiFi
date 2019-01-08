local mq = require "hiwifi.mq"

local string, table, os, tostring, ipairs, tonumber, type = string, table, os, tostring, ipairs, tonumber, type
local DEBUG = false

local action_arg = arg[1]
local down_hour_arg = arg[2]
local down_min_arg = arg[3]
local up_hour_arg = arg[4]
local up_min_arg = arg[5]

local function logger(data)
  if DEBUG == true then
    local util = require "luci.util"
    util.logger(data)
  end
end

local function service_name()
  return "24"
end

local function register_service()
  local service = service_name()
  local url = "http://m.hiwifi.com/api/Router/routerPushAdd"
  local level = 2
  local timeout = 600
  local state = 1
  local rst, msg = mq.init_service(service, url, level, timeout, state)
  if not rst then
    return false
  end
  return true
end

local function notice()
  if not register_service() then
    logger("not register_service 24")
    return false
  end
  local notice_time = os.time()
  local msg = {service = service_name(),
               content = {action = action_arg,
                          close_hour = tonumber(down_hour_arg),
                          close_min = tonumber(down_min_arg),
                          open_hour = tonumber(up_hour_arg),
                          open_min = tonumber(up_min_arg),
                          notice_time = notice_time}
              }
  logger(msg)
  local msg_id = mq.add(msg)
  logger(msg_id)
  return msg_id
end

notice()
