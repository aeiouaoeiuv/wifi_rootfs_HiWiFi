-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local nixio = require "nixio"
local os = os

module "hiwifi.digest"

local function get_md5sum(file)
  local fdi, fdo = nixio.pipe()
  local pid = nixio.fork()
  if pid > 0 then
    fdo:close()
    nixio.waitpid(pid)
    --Thirty-two is the length of md5sum.
    local buffer = fdi:read(32)
    fdi:close()
    return buffer
  elseif pid == 0 then
    fdi:close()
    local null = nixio.open("/dev/null", "w+")
    nixio.dup(fdo, nixio.stdout)
    nixio.dup(null, nixio.stderr)
    null:close()
    fdo:close()
    nixio.exece("/usr/bin/md5sum", {file}, {})
    os.exit(1)
  end
  return nil
end


function md5file(file)
  return get_md5sum(file)
end
