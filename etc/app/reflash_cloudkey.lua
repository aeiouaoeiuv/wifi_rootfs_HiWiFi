local cloudkey_path = "/etc/app/appcloudkey"
local util = require "luci.util"
local fs = require "nixio.fs"
if not fs.access(cloudkey_path) or fs.readfile(cloudkey_path) == "" then
local mobile_app_router = require "hiwifi.mobileapp.router"
local result = mobile_app_router.set_cloudkey()
end
