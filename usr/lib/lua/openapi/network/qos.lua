-- Copyright (c) 2014 HiWiFi Co., Ltd.
-- Author: Longfei Qiao <longfei.qiao@hiwfii.tw>

local os, ipairs, table, string = os, ipairs, table, string
local fs = require("nixio.fs")
local json = require('luci.tools.json')
local util = require("luci.util")
local utils = require("openapi.utils.utils")
local uci = require "luci.model.uci"
local x  = uci.cursor()

module("openapi.network.qos", package.seeall)

---------------------------------------------------------------------------------------
--  7.01 获取 手机端显示 列表需要的信息
---------------------------------------------------------------------------------------
local DEVICES_SPEEDUP_TIME_DEFULT = 3599    --second
local DEVICES_SPEEDUP_LOWEST_DEFULT = 20  --KB/S
local DEVICES_SPEEDUP_PERCENT_DEFULT = 99

function set_bw(data)
  --x:foreach("smartqos", "smartqos", 
  --function (s)
  --end)
  if type(data) ~= "table" then
    utils.ret_output("1", "data type error", "")
  end
  local up = data["up"] or "4000"
  local down = data["down"] or "4000"
  
  util.exec("uci set smartqos.@smartqos[0].up="..up.." 2>/dev/null")
  util.exec("uci set smartqos.@smartqos[0].down="..down.." 2>/dev/null")
  util.exec("uci commit smartqos")

  return utils.ret_output("0", "set_bw success", "")
end

function get_bw()
  local data = {}

  local up = util.exec("uci get smartqos.@smartqos[0].up 2>/dev/null")
  local down = util.exec("uci get smartqos.@smartqos[0].down 2>/dev/null")

  data.up = util.trim(up)
  data.down = util.trim(down)

  return utils.ret_output("0", "get_bw success", data)
end

function start()
  utils.exec("/etc/init.d/smartqos start")
  return utils.ret_output("0", "start success", "")
end

function stop()
  utils.exec("/etc/init.d/smartqos stop")
  return utils.ret_output("0", "stop success", "")
end

function restart()
  utils.exec("/etc/init.d/smartqos restart")
  return utils.ret_output("0", "restart success", "")
end

---------------------------------------------------------------------------------------
--	2.45 设置
---------------------------------------------------------------------------------------

function set_qos()
	local http = require "luci.http"
	
	-- 参数

	local macReq = string.upper(luci.http.formvalue("mac"))
	local upReq = luci.http.formvalue("up")
	local downReq = luci.http.formvalue("down")
	local guaranty_upReq = tonumber(luci.http.formvalue("guaranty_up"))
	local guaranty_downReq = tonumber(luci.http.formvalue("guaranty_down"))
	local nameReq = luci.http.formvalue("name")
	local datatypes = require "luci.cbi.datatypes"
	
	if nameReq ~= nil and nameReq ~= "" then
	  nameReq = luci.util.trim(nameReq)
    nameReq = luci.util.filter_htmltags(nameReq)
	end
	
	-- 返回值
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	
	--插入运算代码
	if not datatypes.macaddr(macReq) then
		codeResp = 521
	else 
		if tonumber(upReq) and tonumber(downReq) then 
		
			--保存
			local sets = require "hiwifi.collection.sets"
			local device_qos_guaranty = require "hiwifi.device_qos_guaranty"
			local file_content = fs.readfile(DEVICE_QOS_FILE)
			local contant = {}
			if file_content ~= nil then
				for k in string.gmatch(file_content, "[^\n]+") do
					sets.add(contant, k)
				end
			end
			local have_set = false
			local lines = sets.to_list(contant)
			local lines_save = {}
			
			if guaranty_upReq == nil or guaranty_upReq < 0 then
			 guaranty_upReq = 0
			end
			if guaranty_downReq == nil or guaranty_downReq < 0 then
			 guaranty_downReq = 0
			end
			
			if tonumber(upReq)> -1 and tonumber(downReq)> -1 then 	--添加
				luci.util.exec('echo "'..macReq..' '..downReq..' '..upReq..' '..guaranty_downReq..' '..guaranty_upReq..' " >/proc/net/smartqos/config')
				
				--保存
				for _,l in pairs(lines) do
					local mac,up,down,name= l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+([^%s%s]+)')
					if mac == macReq then
						lines_save[#lines_save+1] = macReq.." "..downReq.." "..upReq.." "..nameReq
						have_set = true
					else 
						lines_save[#lines_save+1] = l
					end
				end
				if not have_set then
					lines_save[#lines_save+1] = macReq.." "..downReq.." "..upReq.." "..nameReq
				end
				fs.mkdirr(fs.dirname(DEVICE_QOS_FILE))
				fs.writefile(DEVICE_QOS_FILE, table.concat(lines_save, "\n"))
				
				device_qos_guaranty.add(macReq, guaranty_downReq, guaranty_upReq)
				
			elseif tonumber(upReq) == -1 and tonumber(downReq) == -1 then	--删除
				
				luci.util.exec('echo "'..macReq..' '..downReq..' '..upReq..' -1 -1 " >/proc/net/smartqos/config')
				
				--保存
				for _,l in pairs(lines) do
					local mac,up,down= l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)')
					if mac ~= macReq then
						lines_save[#lines_save+1] = l 
					end
				end
				fs.mkdirr(fs.dirname(DEVICE_QOS_FILE))
				fs.writefile(DEVICE_QOS_FILE, table.concat(lines_save, "\n"))
				
				device_qos_guaranty.del(macReq)
				
			else 
				codeResp = 550
			end
		else 
			codeResp = 550
		end 
	end
	
	-- 返回值及错误处理
	if (codeResp == 0) then 
	else 
		msgResp = luci.util.get_api_error(codeResp)
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	
	http.write_json(arr_out_put)
end

---------------------------------------------
--通知qos网络变更
---------------------------------------------
function hwf_sqos_setup_tc_qdisc()
  luci.util.delay_exec("source /lib/functions/hwf_sqos_tc_actions.sh && hwf_sqos_setup_tc_qdisc &", 3)
end

--获取加速列表
function get_part_speedup_list(args)
  -- 参数
  -- 手机 app 型号
  local ios_client_ver = args["ios_client_ver"]

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  local list={}
  
  --插入运算代码  
  
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    arr_out_put["list"] = {}
    
    local device_list = util.get_device_list_brief()
    local net = require "hiwifi.net"
    local mac_name_hash = {}
    
    --DHCP (获取 ip 及 name)
    local dhcp_devicesResp = net.get_dhcp_client_list()
    if dhcp_devicesResp then
      for _, net in ipairs(dhcp_devicesResp) do 
        mac_name_hash[net['mac']] = net['name']
      end
    end
    
    -- 别名列表 (会覆盖 dhcp 名称)
      local re_name
    local device_names = require "hiwifi.device_names"
      local device_name_all = device_names.get_all()
      table.foreach(device_name_all, function(mac_one, re_name)
        mac_name_hash[mac_one] = re_name
      end)
      
      -- 获取当前加速状态
      local part_speedup = require("hiwifi.mobileapp.part_speedup")
      local mac_ing,time_ing = part_speedup.get_device_speedup()
      
      local real_name
    for i,device in ipairs(device_list) do
      
      if not mac_name_hash[device["mac"]] or mac_name_hash[device["mac"]] == "" then
        real_name = "未知"
      else 
        real_name = mac_name_hash[device["mac"]]
      end
      arr_out_put["list"][i] = {}
      arr_out_put["list"][i]["item_id"] = device["mac"]
      arr_out_put["list"][i]["rpt"] = device["rpt"]
      arr_out_put["list"][i]["name"] = real_name
      arr_out_put["list"][i]["icon"] = "http://s.hiwifi.com/m/pc_icon.png"
      arr_out_put["list"][i]["time_total"] = DEVICES_SPEEDUP_TIME_DEFULT
      arr_out_put["list"][i]["time_over"] = DEVICES_SPEEDUP_TIME_DEFULT 
      arr_out_put["list"][i]["status"] = 0
        
      if mac_ing then
        if string.lower(mac_ing) == string.lower(device["mac"])then 
          arr_out_put["list"][i]["time_over"] = time_ing
          arr_out_put["list"][i]["status"] = 1
        end       
      end
    end
    
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  local rst = {}
  rst["data"] = arr_out_put
  rst["code"] = codeResp
  rst["msg"] = msgResp
  
  return rst
end

--- 设置单项加速
function set_part_speedup(args)
  
  -- 参数
  -- 手机 app 型号
  local ios_client_ver = args["ios_client_ver"]
  local item_id = args["item_id"]
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  local dataResp = {}
  
  --插入运算代码  
  local part_speedup = require("hiwifi.mobileapp.part_speedup")
  part_speedup.set_device_speedup(item_id,DEVICES_SPEEDUP_PERCENT_DEFULT,DEVICES_SPEEDUP_TIME_DEFULT,DEVICES_SPEEDUP_LOWEST_DEFULT)
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

--- 取消单项加速
function cancel_part_speedup(args)
  -- 参数
  -- 手机 app 型号
  local ios_client_ver = args["ios_client_ver"]
  local item_id = args["item_id"]

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local dataResp={}
  local arr_out_put={}
  
  --插入运算代码  
  local part_speedup = require("hiwifi.mobileapp.part_speedup")
  part_speedup.cancel_device_speedup(item_id)
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end
