local tostring, tonumber, os, ipairs, table = tostring, tonumber, os, ipairs, table
local json = require("luci.tools.json")
local util = require("luci.util")
local http_luci = require("luci.http")
local http_socket = require("socket.http")
local DEBUG = false

module("openapi.network.wireless", package.seeall)

function debug(msg)
  if DEBUG == true then
    util.logger(msg)
  end
end

function set_ssid(data)
  debug("==================== set_ssid in ===============")
  debug(data)

  local output = {}
  local ssid = data["ssid"]

  if ssid == "" or ssid == nil then
    output["code"] = "10125"
    output["msg"] = "data type error"
    output["data"] = ""

    return output
  end

  local netmd = require "luci.model.network".init()
  local status = require "luci.tools.status"
  local device = status:wifi_networks()[1]["device"]..".network1"
  local net = netmd:get_wifinet(device)

  net:set("ssid",ssid)
  netmd:commit("wireless")
  netmd:save("wireless")
  os.execute("/usr/sbin/hwf-at 1 wifi")

  output["code"] = "0"
  output["msg"] = "set_ssid success"
  output["data"] = ""

  debug(output)
  debug("==================== set_ssid out ===============")
  return output
end

function get_wifi()
  debug("==================== get_ssid in ===============")
  --参数

  --返回值
  local codeResp = 0
  local msgResp = ""
  local output = {}
  
  local url = "http://127.0.0.1/cgi-bin/turbo/api/wifi/get_status_list"
  local body, code = http_socket.request(url)
  local body_t = json.Decode(body)
  local device_status = body_t['device_status']

  -- 返回值及错误处理
  output["code"] = codeResp
  output["msg"] = msgResp
  output["data"] = device_status

  return output
end

function device_list()
  debug("==================== get_device_list in ===============")
  --参数

  --返回值
  local codeResp = 0
  local msgResp = ""
  local output = {}
  
  local url = "http://127.0.0.1/cgi-bin/turbo/api/network/device_list"
  local body, code = http_socket.request(url)
  local body_t = json.Decode(body)
  local devices = body_t['devices']
  
  -- 返回值及错误处理
  output["code"] = codeResp
  output["msg"] = msgResp
  output["data"] = devices

  return output
end

function set_status(args)
  -- 参数
  local status = args["status"]
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  --插入运算代码
  local net = require "hiwifi.net"
  if status == 0 or status == "0" then
    net.turn_wifi_off()
  elseif status == 1 or status == "1" then
    net.turn_wifi_on()
  else
    codeResp = 20
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
--  打开wifi
---------------------------------------------------------------------------------------
function on()
  return set_status({status=1})
end

---------------------------------------------------------------------------------------
--  关闭wifi
---------------------------------------------------------------------------------------
function off()
   return set_status({status=0})
end

---------------------------------------------------------------------------------------
--  重启wifi
---------------------------------------------------------------------------------------
function restart()
  -- 参数
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  
  local net = require "hiwifi.net"
  if not net.get_wifi_bridge() then
    util.delay_exec("env -i /sbin/wifi >/dev/null 2>&1", 3)
  else
    util.delay_exec("env -i /sbin/ifup wan >/dev/null 2>&1", 3)
  end

  return arr_out_put
end

--------------------------------------------------------------------
---  获取 wifi 信号强度
--  @param #table args
--------------------------------------------------------------------
function get_txpwr(args)
  -- 参数
  local deviceReq = args["device"]

  -- 返回值
  local txpwrResp
  local codeResp = 0
  local msgResp = ""
  local dataResp={}
  local arr_out_put={}
  
  --插入运算代码
  local netmd = require "luci.model.network".init()
  local net = netmd:get_wifinet(deviceReq)
  
  if net then 
    if net:active_mode()=='Master' then
      txpwrResp = tostring(net:txpwr())
    else 
      codeResp = 1000
    end
  else 
    codeResp = 401
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    dataResp["txpwr"] = txpwrResp
  else 
    msgResp = util.get_api_error(codeResp)
  end
  
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

-----------------------------------------------------------------
---  设置 wifi 信号强度
--  @param #table args
-----------------------------------------------------------------
function set_txpwr(args)
  -- 参数
  local deviceReq = args["device"]
  local txpwrReq = args["txpwr"]

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}

  --插入运算代码
  local arr_dev = util.split(deviceReq, ".")
  local device_name = arr_dev[1]

  local netmd = require "luci.model.network".init()
  local wifidevice = netmd:get_wifidev(device_name)

  if wifidevice then
    wifidevice:set("txpwr", txpwrReq);
    netmd:commit("wireless")
    netmd:save("wireless")
    local net = require "hiwifi.net"
    if not net.get_wifi_bridge() then --桥接状态下 ifup wan 包含  wifi 命令
      util.delay_exec_wifi(0)
    else
      util.delay_exec_ifwanup(0)
    end
  else
    codeResp = 401
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
-- 获取 wifi 信道
---------------------------------------------------------------------------------------
function get_channel(args)
  -- 参数
  local deviceReq = args["device"]
  -- 返回值
  local channelResp
  local channel_autorealResp
  local codeResp = 0
  local msgResp = ""
  local dataResp={}
  local arr_out_put={}
  local is_bridgeResp = 0
  
  --插入运算代码
  local netmd = require "luci.model.network".init()
  local net = netmd:get_wifinet(deviceReq)
  
  if net then 
    if net:active_mode()=='Master' then
      channelResp = tostring(net:channel())
    else 
      codeResp = 1000
    end
  else 
    codeResp = 401
  end
  
  --是否桥接
  local uci = require "luci.model.uci"
  local hiwifi_net = require "hiwifi.net"
  local _uci_real  = uci.cursor()
  local wan_if = _uci_real:get("network", "wan", "ifname")
  local WIFI_IFNAMES = hiwifi_net.get_wifi_ifnames()
  local IFNAME = WIFI_IFNAMES[2]
  if wan_if == IFNAME then
    is_bridgeResp = 1
  end
  
  -- 返回值及错误处理
  if (codeResp == 0) then 
    if(channelResp == "0") then
      local hcwifi = require "hcwifi" 
      local IFNAME = net:ifname()--"wlan0" 
      local KEY_CH = "ch" 
      local channel_autorealResp = hcwifi.get(IFNAME, KEY_CH) 
      dataResp["channel_autoreal"] = channel_autorealResp
    end
    
    -- 获取不到 chnnal 补丁
    if channelResp == nil or channelResp == "" then
      local hiwifi_net = require "hiwifi.net"
      local hcwifi = require "hcwifi"
      local WIFI_IFNAMES = hiwifi_net.get_wifi_ifnames()
      local IFNAME = WIFI_IFNAMES[1]
      local KEY_CH = "ch" 
      channelResp = hcwifi.get(IFNAME, KEY_CH)
    end
  else
    msgResp = util.get_api_error(codeResp)
  end
  
  dataResp["channel"] = channelResp
  dataResp["is_bridge"] = is_bridgeResp
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp
  
  return arr_out_put
end

---------------------------------------------------------------------------------------
-- 设置 wifi 信道
---------------------------------------------------------------------------------------
function set_channel(args)
  -- 参数
  local deviceReq = args["device"]
  local channelReq = args["channel"]
  
  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local arr_out_put={}
  
  --插入运算代码
  
  -- 需要取出  deive_name (radio0)
  local arr_dev = util.split(deviceReq, ".")
  local device_name = arr_dev[1]
  
  local netmd = require "luci.model.network".init()
  local wifidevice = netmd:get_wifidev(device_name)
  
  if wifidevice then
    if tonumber(channelReq) then
      if tonumber(channelReq) >= 0 and tonumber(channelReq) <= 13 then
        wifidevice:set("channel", channelReq);
        netmd:commit("wireless")
        netmd:save("wireless")
        local net = require "hiwifi.net"
        if not net.get_wifi_bridge() then --桥接状态下 ifup wan 包含  wifi 命令
          util.delay_exec_wifi(3)
        else
          util.delay_exec_ifwanup(3)
        end
      else
        codeResp = 523
      end
    else
      codeResp = 523
    end
  else
    codeResp = 401
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
-- 获取 channel rank 状况
---------------------------------------------------------------------------------------
function get_channel_rank()
  -- 参数

  -- 返回值
  local codeResp = 0
  local msgResp = ""
  local rankResp = {}
  local dataResp={}
  local arr_out_put={}
  local is_bridgeResp=0
  
  --插入运算代码
  
  --scan
  local hiwifi_net = require "hiwifi.net"
  local result = hiwifi_net.do_wifi_ctl_scan()
  
  local sleeptimes = 0
  while sleeptimes < 10 do
    --aplist
    local aplist = hiwifi_net.get_aplist()
    if aplist ~= nil and table.getn(aplist) > 0 then
      local i,v
      for i,v in ipairs(aplist) do
        aplist[i]["ssid"] = util.fliter_unsafe(aplist[i]["ssid"])
      end
      --rank
      rankResp = util.get_channel_rank(aplist)
      if rankResp ~= nil and ((0 <= rankResp[1]) and (rankResp[1] <= 1)) then
        break
      end
    end
    os.execute("sleep 1")
    sleeptimes = sleeptimes + 1
  end

  -- 返回值及错误处理
  if (codeResp == 0) then 
  else 
    msgResp = util.get_api_error(codeResp)
  end

  dataResp["rank"] = rankResp
  arr_out_put["code"] = codeResp
  arr_out_put["msg"] = msgResp
  arr_out_put["data"] = dataResp

  return arr_out_put
end
