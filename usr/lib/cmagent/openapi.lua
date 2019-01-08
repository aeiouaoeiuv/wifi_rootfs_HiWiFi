local os, print, type = os, print, type
local cmagent = require("hiwifi.cmagent")
local json = require("hiwifi.json")
local callapi = require("openapi.callapi")

local data = cmagent.parse_data()

local action = data.action
local sign  = data.sign
local body = data.body

--------close stdout and stderr---------
local null = nixio.open("/dev/null", "w+")
local tmp = nixio.dup(nixio.stdout)

nixio.dup(null, nixio.stdout)
nixio.dup(nixio.stdout, nixio.stderr)
--null:close()

function ret(output, code)
  -------open stdout-------
  nixio.dup(tmp, nixio.stdout)
  --tmp:close()

  local code = code or 0
  print(json.encode(output))
  os.exit(code)
end

local output = {}

local body_t = json.decode(body)
if body_t == "" or body_t == nil then
  output["code"] = "10150"
  output["msg"] = "data type must be application/json"
  ret(output, 0)
end

if action == "call" then
  output = callapi.callapi(body, sign)
elseif action == "bind" then
  output = callapi.bind(body)
elseif action == "unbind" then
  output = callapi.unbind(body)
else
  output["code"] = "10160"
  output["msg"] = "unknow action"
end

ret(output, 0)
