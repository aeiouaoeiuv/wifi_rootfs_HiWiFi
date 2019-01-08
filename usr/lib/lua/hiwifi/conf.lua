-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

module "hiwifi.conf"

-- The root path of the internal storage, without trailing slash.
disk_path = "/tmp/data"

-- The root path of memory file system.
mem_path = "/tmp"

-- The path to keep the downloading firmware.
firmware_path = "/tmp/upgrade"

-- The file name of Lua interpreter.
lua_bin_file = "/usr/bin/lua"
