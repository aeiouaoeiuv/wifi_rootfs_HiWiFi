-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local pcall = pcall
local json = require "luci.tools.json"

module "hiwifi.json"

---Encodes to a JSON string.
--@param object the given object to be encoded
--@return the encoded string
function encode(object)
  return json.Encode(object)
end

---Decodes a JSON string to table.
--@param str the given JSON string
--@return the decoded table, or nil if failed
function decode(str)
  local ok, result = pcall(json.Decode, str)
  return ok and result or nil
end
