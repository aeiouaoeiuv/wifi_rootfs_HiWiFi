local fs = require "nixio.fs"
local util = require "luci.util"
local today_s = util.get_date_format()
fs.remove("/tmp/data/traffic_his_2d")
fs.remove("/tmp/data/traffic_total_his_2d")
local traffic_folder = "/tmp/data/traffic_his/"
local traffic_folder_today = traffic_folder..today_s.."/"
local traffic_file_today = traffic_folder_today.."total"
local device_list,total = util.get_traffic_list()
local trafic =  tonumber(total["up_max"]) + tonumber(total["down_max"])
local dev_total
local time = os.time()
local dev_taff_hash={}
local mac_t
fs.mkdirr(traffic_folder_today)
os.execute("echo '"..time.." "..trafic.."' >> "..traffic_file_today)
for _,device in ipairs(device_list) do
dev_total = device.up_max + device.down_max
mac_t = util.format_mac_saveable(device.mac)
dev_taff_hash[mac_t] = dev_total
end
local device_list_brief = luci.util.get_device_list_brief()
for i, d in ipairs(device_list_brief) do
mac_t = util.format_mac_saveable(d['mac'])
if dev_taff_hash[mac_t] then
dev_total = dev_taff_hash[mac_t]
else
dev_total = 0
end
os.execute("echo '"..time.." "..dev_total.."' >> "..traffic_folder_today..mac_t)
end
local total_traffic_folder = "/tmp/data/traffic_total_his/"
local total_traffic_folder_today = total_traffic_folder..today_s.."/"
local total_traffic_file_today = total_traffic_folder_today.."total"
local device_list = util.get_traffic_total_list()
local _,_,_,_,_,_,local_mac_1,_,_,local_mac_2 = util.get_lan_wan_info("lan")
if not local_mac_1  then local_mac_1 = local_mac_2 end
local total_trafic =  tonumber(total["up_max"]) + tonumber(total["down_max"])
local dev_total
local dev_taff_hash={}
local mac_t
fs.mkdirr(total_traffic_folder_today)
for _,device in ipairs(device_list) do
dev_total = device.up + device.down
mac_t = util.format_mac_saveable(device.mac)
dev_taff_hash[mac_t] = dev_total
if util.format_mac(mac_t) == util.format_mac(local_mac_1) then
util.file_number_up(total_traffic_file_today,dev_total)
end
end
local device_list_brief = luci.util.get_device_list_brief()
for i, d in ipairs(device_list_brief) do
mac_t = util.format_mac_saveable(d['mac'])
if dev_taff_hash[mac_t] then
dev_total = dev_taff_hash[mac_t]
else
dev_total = 0
end
util.file_number_up(total_traffic_folder_today..mac_t,dev_total)
end
