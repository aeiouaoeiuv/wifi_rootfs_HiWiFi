-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local io = io
local json = require "hiwifi.json"

module "hiwifi.cmagent"

--- Parses the input data for a CMAgent executor.
-- @return a table contains string key-value pairs
function parse_data()
  local data = json.decode(io.read("*a"))
  io.input():close()
  return data
end
