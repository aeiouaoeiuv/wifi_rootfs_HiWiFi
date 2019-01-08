--  HiWiFi message queue
--  Author  Chaogang Liu  <chaogang.liu@hiwifi.tw>
--  Copyright 2014
local require = require
local sys = require "hiwifi.sys"
local lock = require "hiwifi.lock"
local fs = require "nixio.fs"
local json = require "hiwifi.json"
local tonumber, tostring, table, os, string, pcall = tonumber, tostring, table, os, string, pcall
local ipairs, type = ipairs, type

module "hiwifi.mq"

local MQ_PATH = "/var/data/hiwifimq"
local MQ_SERVICE_INDEX = MQ_PATH.."/service_index"
local DEFAULT_SERVICE_URL = "http://m.hiwifi.com/api/Router/routerPushAdd"
local DEFAULT_SERVICE_NAME = "default"
local DEFAULT_SERVICE_LEVEL = 10
local DEFAULT_SERVICE_TIMEOUT = 300
local DEFAULT_SERVICE_STATE = 1
local DEBUG = false
local BACKUP_MQ = false

local function logger(data)
  if DEBUG == true then
    local luci_util = require "luci.util"
    luci_util.logger(data)
  end
end

local function add_log(str)
  local file = "/tmp/log/mq_add.log"
  local logstr = fs.readfile(file) or "" 
  if str and #str > 10000 then
    logstr = ""
  end
  fs.writefile(file, logstr .. "\n" .. tostring(str))
end

--- Send message
-- @param #string msg Message content
-- @return #string Message id
local function send(data)
  local ltn12 = require "ltn12"
  local body = data.message
  local url = data.url
  local post_req = {
    url = url,
    source = ltn12.source.string(body),
    method = "POST",
    headers = {
      ["Content-Length"] = #body
    }
  }
  logger(url)
  logger(body)
  add_log(body)
  local util = require "hiwifi.util"
  local resp = util.download_to_string(post_req)
  logger(resp)
  return resp
end

local function build_index_line(service, url, level, timeout, state)
  local state_str = 0
  if state == 1 or state == "1" then
    state_str = 1
  end
  return ""..service.." "..url.." "..tonumber(level).." "..tonumber(timeout).." "..state_str
end

local function build_index_table(line)
  local col_count = 1
  local line_data = {}
  for col_val in string.gmatch(line, "(%S+)") do
    line_data[col_count] = col_val
    col_count = col_count + 1
  end
  local table = {service=line_data[1],
          url=line_data[2],
          level=line_data[3],
          timeout=line_data[4],
          state=line_data[5]}
  return table
end

local function build_index_line_from_table(line_table)
  local line_data = {}
  line_data[1] = line_table['service']
  line_data[2] = line_table['url']
  line_data[3] = tonumber(line_table['level'])
  line_data[4] = tonumber(line_table['timeout'])
  line_data[5] = line_table['state']
  return table.concat(line_data, " ")
end

local function get_inbox(service)
  return MQ_PATH.."/"..service.."/inbox"
end

local function get_sent(service)
  return MQ_PATH.."/"..service.."/sent"
end

local function get_removed(service)
  return MQ_PATH.."/"..service.."/removed"
end

local function validate(service, url, level, timeout)
  if not string.match(service, "^[a-zA-Z0-9][a-zA-Z0-9_%-]*$") then
    return false, 'service error'
  end
  if not string.match(url, "^http[s]?://[%w%.%-%?%%&=_/]+$") then
    return false, 'url error'
  end
  if level then
    if not string.match(level, "^%d+$") then
      return false, 'level error'
    end
  end
  if timeout then
    if not string.match(timeout, "^%d+$") then
      return false, 'timeout error'
    end
  end
  return true
end

local function load_service_file()
  local index_file_content = ''
  local index_file_stat = fs.stat(MQ_SERVICE_INDEX)
  if index_file_stat then
    index_file_content = fs.readfile(MQ_SERVICE_INDEX)
  end
  local new_index_file = {}
  local find_service = false
  local count = 1
  for line in string.gmatch(index_file_content, "(%C+)%c") do
    local line_data = build_index_table(line)
    new_index_file[count] = line_data
    count = count + 1
  end
  return new_index_file
end

local function save_service_file(data)
  local content_table = {}
  for k, v in ipairs(data) do
    content_table[#content_table + 1] = build_index_line_from_table(v)
  end
  local index_file_content = table.concat(content_table, "\n").."\n"
  local rst = fs.writefile(MQ_SERVICE_INDEX, index_file_content)
  logger(rst)
  return rst
end

--- Update service key with value
-- @param #string service Service name
-- @param #string key Key of service
-- @param #string value New value
local function update_value(service, key, value)
  local service_index_lk = lock.trylock("service_index")
  if service_index_lk == nil then
    return false, 'locking'
  end
  local servie_index = load_service_file()
  for k, v in ipairs(servie_index) do
    local service_table = v
    if service_table['service'] == service then
      service_table[key] = value
    end
  end
  local rst = save_service_file(servie_index)
  lock.unlock(service_index_lk)
  return rst
end

function has_service(service_name)
  local servie_index = load_service_file()
  for k, v in ipairs(servie_index) do
    if v['service'] == service_name then
      return true
    end
  end
  return false
end

local function get_defualt_service()
  return DEFAULT_SERVICE_NAME
end

--- Add default service
function add_default_service()
  return init_service(DEFAULT_SERVICE_NAME, DEFAULT_SERVICE_URL, DEFAULT_SERVICE_LEVEL,
    DEFAULT_SERVICE_TIMEOUT, DEFAULT_SERVICE_STATE)
end

local function start_process()
  fs.writefile(MQ_PATH.."/processing", "1")
end

local function stop_process()
  fs.writefile(MQ_PATH.."/processing", "0")
end

local function is_processing()
  if fs.readfile(MQ_PATH.."/processing") == "1" then
    return true
  end
  return false
end

function init_mq()
  stop_process()
end

local function add_contab()
  -- MOVE TO /etc/cron/1/mq_process_job.script
end

local function set_has_job()
  fs.writefile(MQ_PATH.."/has_job", "1")
  add_contab()
end

local function has_job()
  if fs.readfile(MQ_PATH.."/has_job", 1) == "1" then
    return true
  end
  return false
end

--- Add message
-- @param #table msg Message data
-- @return #string Message id
function add(msg)
  logger("Add msg")
  logger(msg)
  local msg_service = msg.service
  logger(msg_service)
  if msg_service == nil then
    msg_service = get_defualt_service()
  end
  if not has_service(msg_service) then
    if get_defualt_service() == msg_service then
      logger("add_default_service")
      local code, msg = add_default_service()
      if code ~= true then
        return code, msg
      end
    else
      logger("Not found service")
      return false, "Not found service "..tostring(msg_service)
    end
  end

  local msg_content = msg.content
  logger(msg_content)
  local msg_content_str
  if type(msg_content) == "table" then
    msg_content_str = json.encode(msg_content)
  else
    msg_content_str = msg_content
  end
  logger(msg_content_str)
  local tmp_file = sys.exec("mktemp "..get_inbox(msg_service).."/hwfmq.XXXXXX 2>/dev/null")
  if tmp_file then
    local msg_file_path = string.gmatch(tmp_file,"(%C+)%c")()
    if msg_file_path and msg_file_path ~= "" then
      local rst = fs.writefile(msg_file_path, msg_content_str)
      if rst then
        set_has_job()
        local msg_id = fs.basename(msg_file_path)
        return msg_id
      end
    end
  end
  return false
end

--- Init service
-- @param #string service Service name
-- @param #string url Service url
-- @param #string level level (1..n)
-- @param #string timeout timeout (second)
-- @param #string state state (1 or 0)
function init_service(service, url, level, timeout, state)
  local vali_code, vali_msg = validate(service, url, level, timeout)
  if vali_code ~= true then
    return vali_code, vali_msg
  end
  local level_tmp = 40
  if level then
     level_tmp = tonumber(level)
  end
  local timeout_tmp = 300
  if timeout then
     timeout_tmp = tonumber(timeout)
  end
  local state_tmp = 0
  if state == 1 or state == "1" then
     state_tmp = state
  end
  local service_index_lk = lock.trylock("service_index")
  if service_index_lk == nil then
    return false, 'locking'
  end
  local s_dir = MQ_PATH.."/"..service
  if fs.stat(s_dir) == nil then
    fs.mkdirr(s_dir)
    fs.mkdir(s_dir.."/inbox")
    fs.mkdir(s_dir.."/sent")
    fs.mkdir(s_dir.."/removed")
  end
  local index_file_content = ''
  local index_file_stat = fs.stat(MQ_SERVICE_INDEX)
  if index_file_stat then
    index_file_content = fs.readfile(MQ_SERVICE_INDEX)
  end
  local new_index_file = {}
  local find_service = false
  local count = 1
  for line in string.gmatch(index_file_content, "(%C+)%c") do
    if string.find(line, "^"..service.." ") then
      find_service = true
      local add_line = build_index_line(service, url, level_tmp, timeout_tmp, state_tmp)
      logger(add_line)
      new_index_file[count] = add_line
    else
      new_index_file[count] = line
    end
    count = count + 1
  end
  if find_service ~= true then
    local add_line = build_index_line(service, url, level_tmp, timeout_tmp, state_tmp)
    logger(add_line)
    new_index_file[count] = add_line
  end
  fs.writefile(MQ_SERVICE_INDEX, table.concat(new_index_file, "\n").."\n")
  lock.unlock(service_index_lk)
  return true
end

function disable_service(service)
  return update_value(service, 'state', 0)
end

function enable_service(service)
  return update_value(service, 'state', 1)
end

--- Process the service
-- @param #string service Service name
local function process_service(service)
  local service_name = service['service']
  local service_url = service['url']
  local level = tonumber(service['level'])
  local timeout = tonumber(service['timeout'])
  local state = service['state']
  local inbox_dir = get_inbox(service_name)
  local removed_dir = get_removed(service_name)
  local sent_dir = get_sent(service_name)
  local files = fs.dir(inbox_dir)
  local tosend_files = {}
  local timeout_files = {}
  if files ~= nil then
    local msgs = {}
    local file
    local file_name
    local has_msg = false
    local sub_msgs = {}
    local now = os.time()
    local ctime
    file_name = files()
    while file_name do
      file = inbox_dir.."/"..file_name
      local file_stat = fs.stat(file)
      if file_stat then
        if file_stat['type'] == "reg" then
          ctime = file_stat['mtime']
          if (tonumber(ctime) + tonumber(timeout) > tonumber(now)) then
            has_msg = true
            local msg_data = {}
            local content = fs.readfile(file)
            local content_obj = json.decode(content)
            if content_obj then
              msg_data['data'] = content_obj
            else
              msg_data['data'] = content
            end
            sub_msgs[#sub_msgs + 1] = msg_data
            tosend_files[#tosend_files + 1] = file
          else
            timeout_files[#timeout_files + 1] = file
          end
        end
      end
      file_name = files()
    end
    for k, timeout_file in ipairs(timeout_files) do
      if BACKUP_MQ == true then
        fs.move(timeout_file, removed_dir.."/"..fs.basename(timeout_file))
      else
        fs.unlink(timeout_file)
      end
    end
    if has_msg == true then
      local auth = require "auth"
      local r_token = auth.get_token("hiwifimq")
      msgs['rank'] = level
      msgs['r_ctime'] = os.time()
      msgs['timeout'] = timeout
      msgs['r_token'] = r_token
      msgs['type'] = service_name
      msgs['sub_msg'] = sub_msgs
      local json_str = json.encode(msgs)
      local sendrst = send({url=service_url, message=json_str})
      local send_model = json.decode(sendrst)
      if send_model then
        if send_model['code'] then
          for k, tosend_file in ipairs(tosend_files) do
            if BACKUP_MQ == true then
              fs.move(tosend_file, sent_dir.."/"..fs.basename(tosend_file))
            else
              fs.unlink(tosend_file)
            end
          end
        end
      end
    end
  end
end

local function do_process_service()
  local servie_index = load_service_file()
  for k, v in ipairs(servie_index) do
    local service = v
    logger(service)
    local state = service['state']
    if state == "1" or state == 1 then
      local function inner_process_service()
        process_service(service)
      end
      local ret = pcall(inner_process_service)
      logger("pcall ret")
      logger(ret)
    end
  end
end

--- Process message queue
function process()
  logger("process send mq")
  local mq_process_lk = lock.trylock("mq_process")
  if mq_process_lk == nil then
    logger("locking mq_process")
    return false, 'locking mq_process'
  end
  if is_processing() then
    logger("processing")
    return false, 'processing'
  end
  start_process()
  logger("pcall(do_process_service)")
  local function inner_do_process_service()
    do_process_service()
  end
  pcall(inner_do_process_service)
  logger("lock.unlock(mq_process_lk)")
  lock.unlock(mq_process_lk)
  stop_process()
  logger("stop_process")
  return true
end

--- Clear service inbox
function clear_inbox(service_name)
  local dir = get_inbox(service_name)
  local file_stat = fs.stat(dir)
  if file_stat and file_stat.type == 'dir' then
    local files = fs.dir(dir)
    local file_name = files()
    while file_name do
      logger("unlink "..dir.."/"..file_name)
      fs.unlink(dir.."/"..file_name)
      file_name = files()
    end
    fs.mkdir(dir)
  end
end
