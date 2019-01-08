--[[
	Led api LED灯控制
	Author Liu Chaogang  <chaogang.liu@hiwifi.tw>
	Copyright	2014
]]--

local os, type, string, tonumber, tostring = os, type, string, tonumber, tostring
local util = require "luci.util"
local fs = require "nixio.fs"
local led_disable_file = '/etc/config/led_disable'

module("openapi.system.led",package.seeall)

local function set_wifi_led_status(ifname, status)
  local hcwifi = require "hcwifi"
  hcwifi.set(ifname, "led", status)
end

---------------------------------------------------------------------------------------
--  设置所有 wifi 的 LED 状态
---------------------------------------------------------------------------------------
local function set_all_wifi_led_status(status)
  local hiwifi_net = require "hiwifi.net"
  local WIFI_IFNAMES, WIFI_IFNAMES2 = hiwifi_net.get_wifi_ifnames()
  if WIFI_IFNAMES and WIFI_IFNAMES[1] then
    set_wifi_led_status(WIFI_IFNAMES[1], status)
  end
  if WIFI_IFNAMES2 and WIFI_IFNAMES2[1] then
    set_wifi_led_status(WIFI_IFNAMES2[1], status)
  end
end

---------------------------------------------------------------------------------------
--  获取 LED 状态
---------------------------------------------------------------------------------------
function get_status()
  -- 参数

  -- 返回值
  local statusResp
  local codeResp = 0
  local msgResp = ""
  local dataResp = {}
  local arr_out_put = {}

  --插入运算代码
  if fs.access(led_disable_file) then 
    statusResp = 0
  else 
    statusResp = 1
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    dataResp["status"] = statusResp
  else 
    msgResp = util.get_api_error(codeResp)
  end

  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp

  return arr_out_put
end

---------------------------------------------------------------------------------------
---  设置 LED 状态
--  @param #table args 参数 {status=0}, {status=1}
---------------------------------------------------------------------------------------
function set_status(args)
  -- 参数
  local statusReq = args["status"]

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  --插入运算代码
  if statusReq == 0 or statusReq == "0" then 
    os.execute("touch "..led_disable_file)
    os.execute("setled off green system && setled off green internet && echo 0 > /proc/hiwifi/eth_led")
    set_all_wifi_led_status("0")
  else
    os.execute("rm -rf "..led_disable_file)
    os.execute("setled timer green system 1000 1000 && setled on green internet && echo 1 > /proc/hiwifi/eth_led")
    set_all_wifi_led_status("1")
  end

  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = util.get_api_error(codeResp)
  end

  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  return arr_out_put
end

---------------------------------------------------------------------------------------
--  打开 LED
---------------------------------------------------------------------------------------
function on()
  return set_status({status=1})
end

---------------------------------------------------------------------------------------
--  关闭 LED
---------------------------------------------------------------------------------------
function off()
  return set_status({status=0})
end
