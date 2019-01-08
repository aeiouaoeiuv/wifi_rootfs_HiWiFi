--[[
	在线情况接口
	Author Liu Chaogang  <chaogang.liu@hiwifi.tw>
	Copyright	2014
]]--

local os, type, string, tonumber, tostring, table, ipairs = os, type, string, tonumber, tostring, table, ipairs
local util = require "luci.util"
local fs = require "nixio.fs"
local io, pairs, pcall = io, pairs, pcall
local require = require

module("openapi.network.online",package.seeall)

local traffic_folder = "/tmp/data/traffic_his/"
local total_traffic_folder = "/tmp/data/traffic_total_his/"

local function is_block(block_list_all, mac, format_mac_func)
  for i=1, #block_list_all do
    if format_mac_func(block_list_all[i]) == format_mac_func(mac)  then
      return 1
    end
  end
  return 0
end

local function get_time_his_device_list(date_n,force_offline)
  local net = require "hiwifi.net"
  local r = {}
  local data = {}
  local popen = io.popen
  local file_path
  local mac_name_hash = {}
  local mac_online_hash = {}
  local mac_type_hash = {}
  local mac_show
  local cont
  local r_out={}
  local interface = "lan"
  local _,_,_,_,_,_,local_mac_1,_,_,local_mac_2 = util.get_lan_wan_info(interface)
  if not local_mac_1  then local_mac_1 = local_mac_2 end
  local file_path_all = traffic_folder..date_n
  local local_mac = util.format_mac("FF:FF:FF:FF:FF:00")
  for mac in popen('ls "'..file_path_all..'" 2>/dev/null'):lines() do  --Linux
    mac_show = util.format_mac(mac)
    -- 排除自己
    if util.available_mac(mac) and local_mac ~= mac_show then
      file_path = file_path_all.."/"..mac
      for line in io.lines(file_path) do
          local time, traffic= line:match('^([^%s]+)%s+([^%s]+)')
          if r[mac_show] then
            r[mac_show] = r[mac_show] + 1
          else
            r[mac_show] = 1
          end
        end
    end
  end
  
  local today = util.get_date_format()
  
  --DHCP (获取 ip 及 name)
  local device_names = require "hiwifi.device_names"
  local dhcp_mac_ip_hash = {}
  local dhcp_devicesResp = net.get_dhcp_client_list()
  if dhcp_devicesResp then
    for _, net in ipairs(dhcp_devicesResp) do 
      mac_name_hash[net['mac']] = net['name']
      dhcp_mac_ip_hash[net['mac']] = net['ip']
      if net['name'] then 
        local result_devicename = device_names.refresh(net['mac'],net['name'])
      end
      if date_n == today then
        local mac_show = util.format_mac(net['mac'])
        if not r[mac_show] then
          r[mac_show] = 1
        end
      end
    end
  end
  
  -- 别名列表 (会覆盖 dhcp 名称)
    local re_name
    local device_name_all = device_names.get_all()
    table.foreach(device_name_all, function(mac_one, re_name)
      mac_name_hash[mac_one] = re_name
    end)
    
    local device_online = util.get_device_list_brief()
    
    if force_offline ~= true then
      for _, d in pairs(device_online) do 
        mac_online_hash[d['mac']] = true
        mac_type_hash[d['mac']] = d['type']
      end
    end
    
    --极卫星
    local mac_rpt_hash = util.get_mac_rpt_hash()
    local is_rpt
    
    --拼接上下行流量及限制
    local traffic_qos_hash_v = util.traffic_qos_hash()
    
    local onl_tmp
    for mac, time in pairs(r) do 
      if mac_name_hash[mac] then 
        re_name = mac_name_hash[mac]
      else
        re_name = ""
      end
      
      if mac_online_hash[mac] and force_offline ~= true then 
        onl_tmp = 1
      else
        onl_tmp = 0
      end
      
      if mac_rpt_hash[mac] then
        is_rpt = true
      else
        is_rpt = false
      end
      
      local type_tmp = mac_type_hash[mac]
      if type_tmp == nil then
         type_tmp = "wifi"
      end
      
      local qos_up_tmp
      local qos_down_tmp
      local qos_status_tmp
      
      if traffic_qos_hash_v[mac] then 
        qos_up_tmp = traffic_qos_hash_v[mac]['up']
        qos_down_tmp = traffic_qos_hash_v[mac]['down']
        qos_status_tmp = 1
      else 
        qos_up_tmp = 0
        qos_down_tmp = 0
        qos_status_tmp = 0
      end
      
      --获取总流量
      local traffic_c=0
      local mac_saveable= util.format_mac_saveable(mac)
      local traffic_c_path = total_traffic_folder..date_n.."/"..mac_saveable
     
      if fs.access(traffic_c_path) then
        traffic_c = tonumber(fs.readfile(traffic_c_path))
      end
      
      table.insert(r_out, {
          ['mac'] =  mac,
          ['name'] = re_name,
          ['online'] = onl_tmp,
          ['type'] = type_tmp,
          ['qos_up'] = qos_up_tmp,
          ['qos_down'] = qos_down_tmp,
          ['qos_status'] = qos_status_tmp,
          ['traffic'] = traffic_c,
          ['comid'] = 0,
          ['time'] = time,
          ['rpt'] = is_rpt
        })
    end
  return r_out
end

---------------------------------------------------------------------------------------
--  获取n天的所有设备连接时间情况
---------------------------------------------------------------------------------------
function history(args)
  -- 参数
  local ios_client_ver = args["ios_client_ver"]
  local android_client_ver = args["android_client_ver"]
  local days = tonumber(args["days"])
  if not days or days < 0 then
    days = 2
  end

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local his_list = {}
  local dataResp = {}
  local arr_out_put={}
  
  --插入运算代码
  local his_list = {}
  if days then
    local time
    for day=1, days do
      time = util.get_date_format(day - 1)
      local forse_offline = nil
      if day > 1 then
        forse_offline = true
      end
        local his_rst = {}
        local function call_get_time_his_device_list()
        his_rst = get_time_his_device_list(time, forse_offline)
        end
        pcall(call_get_time_his_device_list)
        his_list[#his_list + 1] = his_rst
    end
  else
    codeResp = 20
  end

  local mac_filter = require "hiwifi.mac_filter"
  local block_list_all = mac_filter.block_list()
  local format_mac = util.format_mac
  
  --增加字段  block 字段
  for i=1, #his_list do
    local his = his_list[i]
    for j=1, #his do
      his[j]["is_block"] = is_block(block_list_all, his[j]["mac"], format_mac)
    end
  end

  -- 返回值及错误处理
  if (codeResp == 0) then 
  else
    msgResp = util.get_api_error(codeResp)
  end
  
  dataResp["day_list"] = his_list
  dataResp["block_cnt"] = table.getn(block_list_all);
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

--- 获取设备n天内的在线和qos信息
--- TODO 待优化，现在借用了history接口的数据
local function get_time_qos(mac, days)
  local time_qos_table = {}
  local history_data = history({days=days})
  if not history_data then
    return time_qos_table
  end
  local format_mac = util.format_mac
  local day_list = history_data["data"]["day_list"]
  for _, day in ipairs(day_list) do
    local find = false
    for _, device in ipairs(day) do
      if format_mac(device["mac"]) == format_mac(mac) then
        if not find then
          time_qos_table[#time_qos_table + 1] = device
          find = true
        end
      end
    end
    if not find then
      time_qos_table[#time_qos_table + 1] = {mac=mac, online=0}
    end
  end
  return time_qos_table
end

--返回在线时段 max_range 为认为在线的最短时间 如 120 秒，认为比120秒小，认为是连续在线，(打点间隔为 60秒，不要比这个数字小) 
local function get_traffic_day_dev_range(mac,date_n,max_range)
  mac= util.format_mac_saveable(mac)
  local file_path = traffic_folder..date_n.."/"..mac
  local r={}
  local t_det
  local last_time=0
  if  fs.access(file_path) then
    local time_tmp={}
    local idx=1
    local cnt=1
    r[cnt] = {}
    local move_next
    for line in io.lines(file_path) do
      local time, traffic= line:match('^([^%s]+)%s+([^%s]+)')
        --时间数据
        t_det = os.date("*t", tonumber(time))
        if t_det.min < 10 then 
          t_det.min = "0"..t_det.min
        end
        
        if idx == 2 and tonumber(time)-last_time>tonumber(max_range) then -- 寻找结束时间时，时间差小于 max_range 则不记录
        --如果只有一个点，就跳跃了，就抛弃掉
        if r[cnt][2] then 
          cnt = cnt + 1
        end
        r[cnt] = {}
        idx = 1
        r[cnt][idx] = tonumber(t_det.hour..t_det.min)
        else
          r[cnt][idx] = tonumber(t_det.hour..t_det.min)
          idx = 2
        end
        last_time = tonumber(time)
    end
  end
   -- 最后一条数据如果聚现在近，删除掉
  if os.time()-last_time<tonumber(max_range) then 
    r[#r][2]=nil
  end
  return r
end

---------------------------------------------------------------------------------------
--  获取n天内的单设备连接时段情况  (设备页，下)
---------------------------------------------------------------------------------------
function device_history(args)
  -- 参数
  local mac = args["mac"]
  local days = tonumber(args["days"])
  if not days or days < 0 then
    days = 2
  end
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local his_list = {}
  local arr_out_put={}

  --插入运算代码
  if mac and days then
    local time
    for day=1, days do
      time = util.get_date_format(day - 1)
      his_list[#his_list + 1] = get_traffic_day_dev_range(mac, time, 300)
    end
  else
    codeResp = 20
  end
  local time_qos_list = get_time_qos(mac, days)
  for i, time_qos in ipairs(time_qos_list) do
    if his_list[i] then
      time_qos['time_range'] = his_list[i]
    end
  end

  -- 返回值及错误处理
  if (codeResp == 0) then
    dataResp["day_list"] = time_qos_list
  else
    msgResp = util.get_api_error(codeResp)
  end

  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  return arr_out_put
end
