-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local io, os, string = io, os, string

module "hiwifi.sys"

--- Reboots the device.
function reboot()
  os.execute("/sbin/reboot &")
end

--- Copied from luci.
--- Execute given commandline and gather stdout.
-- @param command String containing command to execute
-- @return String containing the command's stdout
function exec(command)
  local pp   = io.popen(command)
  local data = pp:read("*a")
  pp:close()
  return data
end

--- Copied from luci.
--- Return a line-buffered iterator over the output of given command.
-- @param command String containing the command to execute
-- @return      Iterator
function execi(command)
  local pp = io.popen(command)

  return pp and function()
    local line = pp:read()

    if not line then
      pp:close()
    end

    return line
  end
end
