-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

module "hiwifi.strings"

-- The following functions are all copied from luci package.

--- Remove leading and trailing whitespace from given string value.
-- @param str string value containing whitespace padded data
-- @return string value with leading and trailing space removed
function trim(str)
  return str:gsub("^%s*(.-)%s*$", "%1")
end

--- Splits given string on a defined separator sequence and return a table
-- containing the resulting substrings. The optional max parameter specifies
-- the number of bytes to process, regardless of the actual length of the given
-- string. The optional last parameter, regex, specifies whether the separator
-- sequence is interpreted as regular expression.
-- @param str    String value containing the data to split up
-- @param pat    String with separator pattern (optional, defaults to "\n")
-- @param max    Maximum times to split (optional)
-- @param regex   Boolean indicating whether to interpret the separator
--          pattern as regular expression (optional, default is false)
-- @return      Table containing the resulting substrings
function split(str, pat, max, regex)
  pat = pat or "\n"
  max = max or #str

  local t = {}
  local c = 1

  if #str == 0 then
    return {""}
  end

  if #pat == 0 then
    return nil
  end

  if max == 0 then
    return str
  end

  repeat
    local s, e = str:find(pat, c, not regex)
    max = max - 1
    if s and max < 0 then
      t[#t+1] = str:sub(c)
    else
      t[#t+1] = str:sub(c, s and s - 1)
    end
    c = e and e + 1 or #str + 1
  until not s or max < 0

  return t
end
