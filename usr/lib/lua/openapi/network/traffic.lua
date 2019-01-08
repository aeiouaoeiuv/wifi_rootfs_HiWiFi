--[[
	流量接口
	Author Liu Chaogang  <chaogang.liu@hiwifi.tw>
	Copyright	2014
]]--

local os, type, string, tonumber, tostring, table = os, type, string, tonumber, tostring, table
local util = require "luci.util"
local fs = require "nixio.fs"
local io, math = io, math

module("openapi.network.traffic",package.seeall)

local traffic_folder = "/tmp/data/traffic_his/"

--- 流量上下行
-- @return #number up
-- @return #number down
local function get_up_down()
  local traffic_stats = require "hiwifi.traffic_stats"
  local traffic_stats_now = traffic_stats.read_stats()
  return traffic_stats_now['tx_bps'], traffic_stats_now['rx_bps']
end

--- 流量上下行总量
-- @return #number up
-- @return #number down
local function get_total()
  local tx_bps, rx_bps  = get_up_down()
  return (tonumber(tx_bps) or 0) + (tonumber(rx_bps) or 0)
end

--- 计算总流量
local function cal_total(up, down)
  up = up or 0
  down = down or 0
  return up + down
end

--- 历史总流量
local function total_history_list()
  return {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1}
end

local function get_traffic_day(traf_file,date_n,cut_time)
   local r = {}
   local data = {}
   local time_tmp={}
   
   if  fs.access(traf_file) then 
    local idx
    for line in io.lines(traf_file) do
      local time, traffic= line:match('^([^%s]+)%s+([^%s]+)')
        idx = math.modf(tonumber(time)/cut_time+1)*cut_time
        if time_tmp[idx] then
          if tonumber(traffic) > time_tmp[idx] then 
            time_tmp[idx] = tonumber(traffic)
          end  
        else
          time_tmp[idx] = tonumber(traffic)
        end
    end
   end
   
  local begin_time = util.get_time_format(date_n)
  for i=tonumber(begin_time),tonumber(begin_time)+3600*24-1,cut_time do
      if time_tmp[i] then
        table.insert(r, time_tmp[i])
      else
        table.insert(r, -1)
      end
  end
  return r
end

local function get_traffic_day_total(date_n,cut_time)
  local r={}
  local file_path = traffic_folder..date_n.."/total"
  local r_tmp=get_traffic_day(file_path,date_n,cut_time)
  if r_tmp then 
    r = r_tmp
  end
  return r
end

local function get_traffic_day_dev(mac,date_n,cut_time)
  mac= util.format_mac_saveable(mac)
  local file_path = traffic_folder..date_n.."/"..mac
  local r={}
  local r_tmp=get_traffic_day(file_path,date_n,cut_time)
  if r_tmp then 
    r = r_tmp
  end
  return r
end

---------------------------------------------------------------------------------------
--  获取实时流量状态以及历史
---------------------------------------------------------------------------------------
function status_with_history(args)
  -- 参数
  local ios_client_ver = args["ios_client_ver"]

  -- 返回值
  local traffic
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put = {}
  
  -- traffic
  local up, down = get_up_down()
  local total = cal_total(up, down)

  -- 返回值及错误处理
  if (codeResp == 0) then
    dataResp["up"] = up
    dataResp["down"] = down
    dataResp["total"] = total
    dataResp["total_history"] = total_history_list()
  else
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

---------------------------------------------------------------------------------------
--  获取实时流量状态
---------------------------------------------------------------------------------------
function status(args)
  -- 参数
  local ios_client_ver = args["ios_client_ver"]

  -- 返回值
  local traffic
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put={}
  
  -- traffic
  local up, down = get_up_down()
  local total = cal_total(up, down)

  -- 返回值及错误处理
  if (codeResp == 0) then
    dataResp["up"] = up
    dataResp["down"] = down
    dataResp["total"] = total
  else
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp

  return arr_out_put
end

---------------------------------------------------------------------------------------
--  获取n天内的按天累计的宽带使用情况(日线页，上)
---------------------------------------------------------------------------------------
function history(args)
  local days = tonumber(args["days"])
  if not days or days < 0 then
    days = 2
  end

  -- 参数
  local cut_time = 300
  local his_td={}
  local his_ys={}
  local total_cnt = 3600*24/cut_time
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put={}

  --插入运算代码
  local time
  local his_list = {}
  for day=1, days do
    time = util.get_date_format(day - 1)
    his_list[#his_list + 1] = get_traffic_day_total(time, cut_time)
  end

  -- 返回值及错误处理
  if (codeResp == 0) then
    dataResp['day_list'] = his_list
    dataResp["cnt"] = total_cnt
  else
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

---------------------------------------------------------------------------------------
--  获取n天内的单设备每天使用宽带情况(日线页，上)
---------------------------------------------------------------------------------------
function device_history(args)
  -- 参数
  local mac = args["mac"]
  local days = tonumber(args["days"])
  if not days or days < 0 then
    days = 2
  end

  local cut_time = 300
  local total_cnt = 3600*24/cut_time
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put={}

  --插入运算代码
  local his_list = {}
  if mac and days then
    local time
    for day=1, days do
      time = util.get_date_format(day - 1)
      his_list[#his_list + 1] = get_traffic_day_dev(mac, time, cut_time)
    end
  else
    codeResp = 20
  end

  -- 返回值及错误处理
  if (codeResp == 0) then
    dataResp['day_list'] = his_list
    dataResp["cnt"] = total_cnt
  else
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end
