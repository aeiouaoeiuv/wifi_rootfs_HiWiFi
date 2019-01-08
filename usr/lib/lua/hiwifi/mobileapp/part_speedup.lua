--INFO
--操作对象，接口文件为：
--/proc/net/smartqos/monarch
--
--操作行为：
--1 启动单IP加速
--echo "mac  percent  time lowest” > /proc/net/smartqos/monarch
--参数解释
--mac： 希望加速的设备的16进制mac地址
--percent： 整数格式，区间（0 ～100）， 代表这个用户使用的带宽百分比。
--time： 加速的时间周期， 单位为秒，区间（0 ～ 600）秒， 可修改。
--lowest： 最低保证速度
--效果， 该mac用户在time周期内独占percent/100 × 总带宽， 其余设备共用（1 -percent/100）×总带宽。
--
--2 查询
--cat /proc/net/smartqos/monarch
--返回数据的格式与输入一致，特别的是 time会随时间流逝依次减小至0.
--mac percent time

-- speed up part
-- Copyright (c) 2013 Geek-Geek Co., Ltd.
-- Author: wanchao <chao.wang@hiwifi.tw>
local auth = require("auth")
local util = require("hiwifi.util")
local base = require("hiwifi.mobileapp.base")
local strings = require("hiwifi.strings")
local pairs, table ,os, tonumber, tostring, string, require = pairs, table, os, tonumber, tostring, string, require
local fs = require "nixio.fs"
local DEBUG = false

module "hiwifi.mobileapp.part_speedup"

local pairs, table = pairs, table
local QOS_SINGLE_DEVICE_FILE = "/proc/net/smartqos/monarch"
local max_time = 3599
local notice_before_time = 300

local function logger(data)
  if DEBUG == true then
    local util = require "luci.util"
    util.logger(data)
  end
end

--- 取消提醒
local function cancel_notice()
  local alert_cmd = string.format("/etc/app/part_speedup.script remove")
  logger(alert_cmd)
  os.execute(alert_cmd)
  
  local mq = require "hiwifi.mq"
  mq.clear_inbox("22")
end

--- 设置到时提醒
local function delay_notice(mac, time_1)
  local now = os.time()
  local time_alert = tonumber(time_1)
  logger(time_alert)
  if time_alert then
    time_alert = time_alert - notice_before_time
    logger(time_alert)
    if time_alert > 0 then
      local notice_time = now + time_alert
      local notice_time_obj = os.date("*t", notice_time)
      local notice_min = notice_time_obj.min
      local notice_hour = notice_time_obj.hour
      local notice_day = notice_time_obj.day
      local notice_month = notice_time_obj.month
      local alert_cmd = string.format("/etc/app/part_speedup.script set_notice %u %u %u %u %q %u", notice_min, notice_hour, notice_day, notice_month, mac, notice_before_time)
      logger(alert_cmd)
      os.execute(alert_cmd)
    end
  end
end

-- speed up single divice
--@param object the given object to be encoded
--mac：mac
--percent： 1～99
--time： 0 ～ 6000 Second
--Bps：0 ～20000 KB  (Lowest speed)
--@return true or false

function set_device_speedup(mac,percent,time,lowest)
	mac = strings.trim(mac)
	local time_1 = tonumber(time) or max_time
	if time_1 > max_time then
    time_1 = max_time
	end
	local set_qos_single_device = 'echo "'..mac..' '..percent..' '..time_1..' '..lowest..'" > '..QOS_SINGLE_DEVICE_FILE
	logger(set_qos_single_device)
	os.execute(set_qos_single_device)
	cancel_notice()
	delay_notice(mac, time_1)
end

function cancel_device_speedup(mac)
	mac = strings.trim(mac)
	os.execute('echo "'..mac..' 10 0 99" > '..QOS_SINGLE_DEVICE_FILE)
	cancel_notice()
end

function get_device_speedup()
  local file_content = fs.readfile(QOS_SINGLE_DEVICE_FILE)
  local mac,time
  if file_content ~= nil then
 	mac,_,time = file_content:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+')
  end
  return mac,time
end