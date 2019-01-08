module("luci.sauth", package.seeall)
require("luci.util")
require("luci.sys")
require("luci.config")
local nixio = require "nixio"
local fs = require "nixio.fs"
luci.config.sauth = luci.config.sauth or {}
sessionpath = luci.config.sauth.sessionpath
sessiontime = tonumber(luci.config.sauth.sessiontime) or 15 * 60
function clean()
local now   = os.time()
local files = fs.dir(sessionpath)
if not files then
return nil
end
local entries = nixio.util.consume(files)
if #entries > 50 then
for _, file in luci.util.vspairs(entries) do
local fname = sessionpath .. "/" .. file
local stat = fs.stat(fname)
if stat and stat.type == "reg" and stat.mtime + sessiontime < now then
fs.unlink(fname)
end
end
end
end
function prepare()
fs.mkdir(sessionpath, 700)
if not sane() then
error("Security Exception: Session path is not sane!")
end
end
function read(id)
if not id or #id == 0 then
return
end
if not id:match("^%w+$") then
error("Session ID is not sane!")
end
clean()
if not sane(sessionpath .. "/" .. id) then
return
end
fs.utimes(sessionpath .. "/" .. id)
return fs.readfile(sessionpath .. "/" .. id)
end
function sane(file)
return luci.sys.process.info("uid")
== fs.stat(file or sessionpath, "uid")
and fs.stat(file or sessionpath, "modestr")
== (file and "rw-------" or "rwx------")
end
function write(id, data)
if not sane() then
prepare()
end
if not id:match("^%w+$") then
error("Session ID is not sane!")
end
local f = nixio.open(sessionpath .. "/" .. id, "w", 600)
f:writeall(data)
f:close()
end
function kill(id)
if not id:match("^%w+$") then
error("Session ID is not sane!")
end
fs.unlink(sessionpath .. "/" .. id)
end
