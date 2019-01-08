local pcall, dofile, _G = pcall, dofile, _G
module "luci.version"
if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
distname    = ""
distversion = _G.DISTRIB_DESCRIPTION
else
distname    = "OpenWrt Firmware"
distversion = "Attitude Adjustment (r29485)"
end
luciname    = "LuCI Trunk "
luciversion = "trunk+svn8073"
turboname	= "Turbo Wireless"
turboversion	= "T1.6"
default_lan_ip  = "192.168.199.1"
default_password  = "admin"
guide_tag = "201211_chaowang"
svnRevision = "$Revision: 2235 $"
svnRevNum = svnRevision:match("^[^%s]+Revision:%s+(%d+)")
