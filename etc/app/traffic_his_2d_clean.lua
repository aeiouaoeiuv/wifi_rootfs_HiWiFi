local fs = require "nixio.fs"
local traffic_folder = "/tmp/data/traffic_his/"
local total_traffic_folder = "/tmp/data/traffic_total_his/"
local traffic_savedays = 5; --上网累计时长保存填数,至少保留 1 天
local total_traffic_savedays = 10; --上网流量保留天数,至少保留 1天
local util = require "luci.util"
fs.mkdirr(traffic_folder)
fs.mkdirr(total_traffic_folder)
local popen = io.popen
local save_this
for day in popen('ls "'..traffic_folder..'"'):lines() do
save_this=false
for i=0,traffic_savedays-1 do
if(day == util.get_date_format(i)) then
save_this=true
end
end
if not save_this then
fs.remove(traffic_folder..day)
end
end
for day in popen('ls "'..total_traffic_folder..'"'):lines() do
save_this=false
for i=0,total_traffic_savedays-1 do
if(day == util.get_date_format(i)) then
save_this=true
end
end
if not save_this then
fs.remove(total_traffic_folder..day)
end
end
