-- arp.lua version 0.0.1
module("arp", package.seeall)
 
function split(str, pat)
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end
 
function get_mac(ip)
	local	ret = "none"

	if ip == nil or ip == "" then
		return	ret
	end

	for line in io.lines("/proc/net/arp") do
		local	arpinfo = split(line, "%s%s+")

		if #arpinfo > 4 and arpinfo[1] == ip then
			ret = arpinfo[4]
			ret = ret:gsub(":", "")
			ret = ret:upper()
			break
		end
	end
	
	return	ret
end

function get_ip(mac)
	local	ret = "none"

	if mac == nil or mac == "" then
		return	ret
	end

	for line in io.lines("/proc/net/arp") do
		local	arpinfo = split(line, "%s%s+")

		if #arpinfo > 4 and arpinfo[4] == mac then
			ret = arpinfo[1]
			break
		end
	end
	
	return	ret
end

