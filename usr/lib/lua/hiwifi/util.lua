-- Copyright (c) 2012 Elite Co., Ltd.
-- Author: Hong Shen <sh@ikwcn.com>

local io = io
local table = table
local type = type
local string = string
local pairs = pairs

local digest = require "hiwifi.digest"
local ltn12 = require "ltn12"
local fs = require "nixio.fs"
local http = require "socket.http"
local https = require "ssl.https"

module "hiwifi.util"

local function download(param, sink)
  if type(param) == "string" then
    param = {
      url = param
    }
  end
  param['sink'] = sink
  if is_ssl(param['url']) then
    param['verify'] = param['verify'] or 'peer'
    param['capath'] = param['capath'] or '/etc/ca'
    return https.request(param)
  else
    return http.request(param)
  end
end

--- Downloads from a URL to a string.
--- This function will block until download finishes or timeout.
--@param param a table used in luasocket, or just url string
--@return HTTP/HTTPS response body
--@return 1 if succeed to get HTTP response, nil if failed
--@return HTTP status code in response, error message if failed to get response
function download_to_string(param)
  local t = {}
  local sink = ltn12.sink.table(t)
  local res, code = download(param, sink)
  return table.concat(t), res, code
end


--- Downloads from a URL to a local file.
--- This function will block until download finishes or timeout.
--@param param a table used in luasocket, or just url string
--@param file local file name with full path
--return values:
--@r: Execution result, true on success, false on failure.
--@c: Http code, 200 on success, others on failure.
function download_to_file(param, file)
  local sink = ltn12.sink.file(io.open(file, 'w'))
  local r, c = download(param, sink)
  return c
end

--- Downloads from a URL to a local file and checks the md5 checksum.
--- This function will block until download finishes or timeout.
--- If md5 verification fails, the downloaded file is removed.
--@param param a table used in luasocket, or just url string
--@param file local file name with full path
--@param md5 the expected md5 checksum of local file
--@return true if succeed, false if failed
function download_to_file_with_md5_checking(param, file, md5)
  download_to_file(param, file)
  local actual_md5 = digest.md5file(file)
  if actual_md5 ~= md5 then
    fs.remove(file)
    return false
  end
  return true
end

-- Check ssl by url
--@param url
--@return true is ssl (https), false if not https  (may be not "http" too)
function is_ssl(url)
  if string.sub(url, 1, 5) == "https" then
    return true
  else
  	return false
  end
end

-- https curl post
--@param url
--@param params is a table or string
--@return code 0 means ok, response_body will return , or 
--@return msg is error message
--@return response_body is response body
function https_curl_post(url, request_body)
  request_body = request_body or {}
  
  local code=0
  local response_body={}
  local str_request_body
  local result 
  if type(request_body) == "table" then 
    str_request_body = request_body_to_string(request_body)
  elseif type(request_body) == "string" then 
  	str_request_body = request_body
  end
 
  if not is_ssl(url) then
    code=801
  else 
    https.request{
	    url = url,
	    method = "POST",
	    headers = {
	         ["Content-Length"] = string.len(str_request_body),
	         ["Content-Type"] = "application/x-www-form-urlencoded"
	     },
	     source = ltn12.source.string(str_request_body),
	     sink = ltn12.sink.table(response_body)
	}
	result = response_body[1]
	if not response_body[1] then 
	    code=802
	end
  end
  return result,code
end

-- params_to_string
-- @param params is a table 
-- @return str is string (exp.   {code="55",msg="66"}    TO  code=55&msg=66)
function request_body_to_string(params)
  local str_params=""
  local parame_tmp={}
  if type(params) == "table" then 
    for k,v in pairs(params) do
      table.insert(parame_tmp, k.."="..v)
	end
	str_params = table.concat(parame_tmp, "&")
  end
  return str_params
end
