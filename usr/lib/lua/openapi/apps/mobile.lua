--[[
	Mobile api 客户端场景接口合并
	Author Liu Chaogang  <chaogang.liu@hiwifi.tw>
	Copyright	2014
]]--

local os, type, string, tonumber, tostring = os, type, string, tonumber, tostring
local tw = require "tw"
local util = require "luci.util"
local fs = require "nixio.fs"

module("openapi.apps.mobile",package.seeall)

function get_mobi_health(args)
  -- 参数
  -- 手机 app 型号
  --local ios_client_ver = args["ios_client_ver"]

  -- 返回值
  local wifi_sleep_startResp = 0
  local wifi_sleep_endResp = 0
  local led_statusResp

  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put={}
  
  --插入运算代码  
  
  -- wifi_sleep
  local start_tmp,end_tmp = util.get_wifi_sleep()
  if start_tmp then 
    wifi_sleep_startResp,wifi_sleep_endResp = start_tmp,end_tmp
  end
  
  -- led_status
  local led_disable_file = '/etc/config/led_disable'
  if fs.access(led_disable_file) then 
    led_statusResp = 0
  else 
    led_statusResp = 1
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    dataResp["wifi_sleep_start"] = wifi_sleep_startResp
    dataResp["wifi_sleep_end"] = wifi_sleep_endResp
    dataResp["led_status"] = led_statusResp
    dataResp["device_cnt"] = device_cntResp
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

function get_mobi_view_info_out_40(args)
  -- 参数
  -- 手机 app 型号
  --local ios_client_ver = args["ios_client_ver"]

  -- 返回值
  local wifi_sleep_startResp = 0
  local wifi_sleep_endResp = 0
  local traffic_upResp
  local traffic_downResp
  local traffic
  local wifi_swich_statusResp
  local wifi_txpwr_statusResp = 0
  local device_cntResp
  local rom_versionResp
  local ssidResp
  local led_statusResp
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put={}
  
  --插入运算代码  
  
  -- wifi_sleep
  local start_tmp,end_tmp = util.get_wifi_sleep()
  if start_tmp then 
    wifi_sleep_startResp,wifi_sleep_endResp = start_tmp,end_tmp
  end
  
  -- wifi_swich_status
  local wifi_swich_status = util.get_wifi_device_status()
  
  -- wifi_txpwr_status
  local netmd = require "luci.model.network".init()
  local net = netmd:get_wifinet("radio0.network1")
  local txpwrResp 

  if net then 
    if net:active_mode()=='Master' then
      txpwrResp = tostring(net:txpwr())
      if txpwrResp == "140" then
        wifi_txpwr_statusResp = 1
      end
    end
  end
  
  -- led_status
  local led_disable_file = '/etc/config/led_disable'
  if fs.access(led_disable_file) then 
    led_statusResp = 0
  else 
    led_statusResp = 1
  end
  
  -- ssid 
  _,_,_,ssidResp = util.get_wifi_device_status()
  
  -- rom版本
  rom_versionResp = tw.get_version():match("^([^%s]+)")
  
  -- 极卫星个数
  local _,rpt_cnt = util.get_mac_rpt_hash()
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    dataResp["wifi_sleep_start"] = wifi_sleep_startResp
    dataResp["wifi_sleep_end"] = wifi_sleep_endResp
    dataResp["np"] = "" --TODO
    dataResp["wifi_swich_status"] = tonumber(wifi_swich_status)
    dataResp["wifi_txpwr_status"] = wifi_txpwr_statusResp
    dataResp["led_status"] = led_statusResp
    dataResp["rpt_cnt"] = rpt_cnt
    dataResp["rom_version"] = rom_versionResp
    dataResp["ssid"] = ssidResp
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end
