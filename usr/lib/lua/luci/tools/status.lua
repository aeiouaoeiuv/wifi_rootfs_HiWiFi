local io, ipairs, os, tonumber = io, ipairs, os, tonumber
local nfs = require "nixio.fs"
local model_uci = require "luci.model.uci"
local network = require "luci.model.network"
module "luci.tools.status"
local uci =  model_uci.cursor()
function dhcp_leases()
local rv = { }
local leasefile = "/var/dhcp.leases"
uci:foreach("dhcp", "dnsmasq",
function(s)
if s.leasefile and nfs.access(s.leasefile) then
leasefile = s.leasefile
return false
end
end)
local fd = io.open(leasefile, "r")
if fd then
while true do
local ln = fd:read("*l")
if not ln then
break
else
local ts, mac, ip, name = ln:match("^(%d+) (%S+) (%S+) (%S+)")
if ts and mac and ip and name then
rv[#rv+1] = {
expires  = os.difftime(tonumber(ts) or 0, os.time()),
macaddr  = mac,
ipaddr   = ip,
hostname = (name ~= "*") and name
}
end
end
end
fd:close()
end
return rv
end
function wifi_networks()
local rv = { }
local ntm = network.init()
local dev
for _, dev in ipairs(ntm:get_wifidevs()) do
local rd = {
up       = dev:is_up(),
device   = dev:name(),
name     = dev:get_i18n(),
networks = { }
}
local net
for _, net in ipairs(dev:get_wifinets()) do
rd.networks[#rd.networks+1] = {
name       = net:shortname(),
up         = net:is_up(),
mode       = net:active_mode(),
ssid       = net:active_ssid(),
bssid      = net:active_bssid(),
encryption = net:active_encryption(),
frequency  = net:frequency(),
channel    = net:channel(),
signal     = net:signal(),
quality    = net:signal_percent(),
noise      = net:noise(),
bitrate    = net:bitrate(),
ifname     = net:ifname(),
assoclist  = net:assoclist(),
country    = net:country(),
txpower    = net:txpower(),
txpoweroff = net:txpower_offset(),
key	   	   = net:get("key"),
key1	   = net:get("key1"),
encryption_src = net:get("encryption"),
hidden = net:get("hidden"),
ssidprefix = net:get("ssidprefix")
}
end
rv[#rv+1] = rd
end
return rv
end
function dns_resolv()
local rv = { }
local resolvfile = "/tmp/resolv.conf.auto"
uci:foreach("dhcp", "dnsmasq",
function(s)
if s.resolvfile and nfs.access(s.resolvfile) then
resolvfile = s.resolvfile
return false
end
end)
local fd = io.open(resolvfile, "r")
if fd then
while true do
local ln = fd:read("*l")
if not ln then
break
else
local name,ip = ln:match("^(%S+) (%S+)")
if name~="#" then
if name and ip then
rv[#rv+1] = ip
end
end
end
end
fd:close()
end
return rv
end
function wifi_network(id)
local ntm = network.init()
local net = ntm:get_wifinet(id)
if net then
local dev = net:get_device()
if dev then
return {
id         = id,
name       = net:shortname(),
up         = net:is_up(),
mode       = net:active_mode(),
ssid       = net:active_ssid(),
bssid      = net:active_bssid(),
encryption = net:active_encryption(),
encryption_src = net:get("encryption"),
frequency  = net:frequency(),
channel    = net:channel(),
signal     = net:signal(),
quality    = net:signal_percent(),
noise      = net:noise(),
bitrate    = net:bitrate(),
ifname     = net:ifname(),
assoclist  = net:assoclist(),
country    = net:country(),
txpower    = net:txpower(),
txpoweroff = net:txpower_offset(),
key	   = net:get("key"),
key1	   = net:get("key1"),
hidden = net:get("hidden"),
ssidprefix = net:get("ssidprefix"),
device     = {
up     = dev:is_up(),
device = dev:name(),
name   = dev:get_i18n()
}
}
end
end
return { }
end
function global_wan_ifname()
local global_wan_ifname = "eth1"
local wan_ifname_uci = uci:get("network", "wan", "def_ifname")
if wan_ifname_uci then
global_wan_ifname = wan_ifname_uci
end
return global_wan_ifname
end
