local fs   = require "nixio.fs"
local sys  = require "luci.sys"
local init = require "luci.init"
local util = require "luci.util"
local http = require "luci.http"
local nixio = require "nixio", require "nixio.util"
module("luci.dispatcher", package.seeall)
context = util.threadlocal()
i18n = require "luci.i18n"
_M.fs = fs
authenticator = {}
local index = nil
local fi
function build_url(...)
local path = {...}
local url = { http.getenv("SCRIPT_NAME") or "" }
local k, v
for k, v in pairs(context.urltoken) do
url[#url+1] = "/;"
url[#url+1] = http.urlencode(k)
url[#url+1] = "="
url[#url+1] = http.urlencode(v)
end
local p
for _, p in ipairs(path) do
if p:match("^[a-zA-Z0-9_%-%.%%/,;]+$") then
url[#url+1] = "/"
url[#url+1] = p
end
end
return table.concat(url, "")
end
function node_visible(node)
if node then
return not (
(not node.title or #node.title == 0) or
(not node.target or node.hidden == true) or
(type(node.target) == "table" and node.target.type == "firstchild" and
(type(node.nodes) ~= "table" or not next(node.nodes)))
)
end
return false
end
function node_childs(node)
local rv = { }
if node then
local k, v
for k, v in util.spairs(node.nodes,
function(a, b)
return (node.nodes[a].order or 100)
< (node.nodes[b].order or 100)
end)
do
if node_visible(v) then
rv[#rv+1] = k
end
end
end
return rv
end
function error404(message)
luci.http.status(404, "Not Found")
message = message or "Not Found"
require("luci.template")
if not luci.util.copcall(luci.template.render, "error404") then
luci.http.prepare_content("text/plain")
luci.http.write(message)
end
return false
end
function error500(message)
luci.util.perror(message)
if not context.template_header_sent then
luci.http.status(500, "Internal Server Error")
luci.http.prepare_content("text/plain")
luci.http.write(message)
else
require("luci.template")
if not luci.util.copcall(luci.template.render, "error500", {message=message}) then
luci.http.prepare_content("text/plain")
luci.http.write(message)
end
end
return false
end
function authenticator.appauth(validator, accs, default, superkey, randkey)
if superkey and type(superkey) == "string" and superkey:match("^[a-f0-9]+$") and
randkey and type(randkey) == "string" and randkey:match("^[a-f0-9]+$") then
local validate = luci.util.exec(". '/etc/app/applogin.script' ; validate '"..superkey.."' '"..randkey.."'")
if validate == "true\n" then
return default
end
end
if context ~= nil and context.path ~= nil and type(context.path) == "table" and table.getn(context.path) > 0 then
local model = context.path[1]
if model == "admin_mobile" then
luci.http.header("Set-Cookie", "")
return authenticator.htmlauth_moblie(validator, accs, default)
elseif model == "admin_web" then
luci.http.header("Set-Cookie", "")
return authenticator.htmlauth_web(validator, accs, default)
end
end
luci.http.header("Set-Cookie", "")
context.path = {}
local json_msg = '{"code":"700","msg":"not auth."}'
luci.http.write(json_msg)
return false
end
function authenticator.jsonauth(validator, accs, default)
if user and validator(user, pass) and user~="root" then
luci.util.unset_loginlock()
return user
end
context.path = {}
local json_msg = '{"code":"99999","msg":"not auth."}'
luci.http.write(json_msg)
return false
end
function authenticator.htmlauth_web(validator, accs, default)
local user = luci.http.formvalue("username")
local pass = luci.http.formvalue("password")
if not luci.util.is_loginlock() then
if user and validator(user, pass) and user~="root" then
luci.util.unset_loginlock()
return user
end
end
require("luci.i18n")
require("luci.template")
context.path = {}
luci.template.render("admin_web/sysauth", {duser=default, fuser=user})
return false
end
function authenticator.htmlauth_moblie(validator, accs, default)
local user = luci.http.formvalue("username")
local pass = luci.http.formvalue("password")
if not luci.util.is_loginlock() then
if user and validator(user, pass) and user~="root" then
luci.util.unset_loginlock()
return user
end
end
require("luci.i18n")
require("luci.template")
context.path = {}
luci.template.render("admin_mobile/sysauth", {duser=default, fuser=user})
return false
end
function httpdispatch(request, prefix)
luci.http.context.request = request
local r = {}
context.request = r
context.urltoken = {}
local pathinfo = http.urldecode(request:getenv("PATH_INFO") or "", true)
if prefix then
for _, node in ipairs(prefix) do
r[#r+1] = node
end
end
local tokensok = true
for node in pathinfo:gmatch("[^/]+") do
local tkey, tval
if tokensok then
tkey, tval = node:match(";(%w+)=([a-fA-F0-9]*)")
end
if tkey then
context.urltoken[tkey] = tval
else
tokensok = false
r[#r+1] = node
end
end
local stat, err = util.coxpcall(function()
dispatch(context.request)
end, error500)
luci.http.close()
end
function dispatch(request)
	local ctx = context
	ctx.path = request
	local conf = require "luci.config"
	assert(conf.main,
		"/etc/config/luci seems to be corrupt, unable to find section 'main'")
	local lang = util.get_user_lang(http)
	require "luci.i18n".setlanguage(lang)
	local c = ctx.tree
	local stat
	if not c then
		c = createtree()
	end
	local track = {}--当前页面 url地址的 对应 lua文件里面具体定义path对应的对象
	local args = {}
	ctx.args = args
	ctx.requestargs = ctx.requestargs or args
	local n
	local token = ctx.urltoken
	local preq = {}
	local freq = {}
	for i, s in ipairs(request) do
		preq[#preq+1] = s
		freq[#freq+1] = s
		c = c.nodes[s]
		n = i
		if not c then
			break
		end
		util.update(track, c)
		if c.leaf then
			break
		end
	end
	if c and c.leaf then
		for j=n+1, #request do
			args[#args+1] = request[j]
			freq[#freq+1] = request[j]
		end
	end
	ctx.requestpath = ctx.requestpath or freq
	if track.i18n then
		i18n.loadc(track.i18n)
	end
	resource = luci.config.main.resourcebase;
	if (c and c.index) or not track.notemplate then
		local tpl = require("luci.template")
		local media = track.mediaurlbase or luci.config.main.mediaurlbase
		if not pcall(tpl.Template, "themes/%s/header" % fs.basename(media)) then
			media = nil
			for name, theme in pairs(luci.config.themes) do
				if name:sub(1,1) ~= "." and pcall(tpl.Template, "themes/%s/header" % fs.basename(theme)) then
					media = theme
				end
			end
			if media==nil then
				assert(media, "No valid theme found:")
			end
		end
		local function _ifattr(cond, key, val)
			if cond then
				local env = getfenv(3)
				local scope = (type(env.self) == "table") and env.self
				return string.format(
					' %s="%s"', tostring(key),
					luci.util.pcdata(tostring( val
					or (type(env[key]) ~= "function" and env[key])
					or (scope and type(scope[key]) ~= "function" and scope[key])
					or "" ))
				)
			else
				return ''
			end
		end
		tpl.context.viewns = setmetatable({
			write       = luci.http.write;
			include     = function(name) tpl.Template(name):render(getfenv(2)) end;
			translate   = i18n.translate;
			export      = function(k, v) if tpl.context.viewns[k] == nil then tpl.context.viewns[k] = v end end;
			striptags   = util.striptags;
			pcdata      = util.pcdata;
			media       = media;
			theme       = fs.basename(media);
			resource    = resource;
			ifattr      = function(...) return _ifattr(...) end;
			attr        = function(...) return _ifattr(true, ...) end;
		}, {__index=function(table, key)
			if key == "controller" then
				return build_url()
			elseif key == "REQUEST_URI" then
				return build_url(unpack(ctx.requestpath))
			else
				return rawget(table, key) or _G[key]
			end
		end})
	end
	track.dependent = (track.dependent ~= false)
	assert(not track.dependent or not track.auto,
		"Access Violation\nThe page at '" .. table.concat(request, "/") .. "/' " ..
		"has no parent node so the access to this location has been denied.\n" ..
		"This is a software bug, please report this message at " ..
		"http://luci.subsignal.org/trac/newticket"
	)
	if track.sysauth and track.noauth~=true then
		local sauth = require "luci.sauth"
		local authen = type(track.sysauth_authenticator) == "function"
			and track.sysauth_authenticator
			or authenticator[track.sysauth_authenticator]
		local def  = (type(track.sysauth) == "string") and track.sysauth
		local accs = def and {track.sysauth} or track.sysauth
		local sess = ctx.authsession
		local superkey = luci.http.getcookie("superkey")
		local randkey = luci.http.getcookie("rnd")
		local verifytoken = false
		if not sess then
			sess = luci.http.getcookie("sysauth")
			sess = sess and sess:match("^[a-f0-9]*$")
			if sess then
				verifytoken = true
			end
		end
		local sdat = sauth.read(sess) -- return { ["secret"] = "2b4bdac10a99891085c0a525eb206ca2", ["token"] = "2f96bd8a0c8957f307bd44b074e91b39", ["user"] = "root" }
		local user
		if sdat then
			sdat = loadstring(sdat)
			setfenv(sdat, {})
			sdat = sdat()
			if sdat then
				if not verifytoken or ctx.urltoken.stok == sdat.token then
					user = sdat.user
				end
			end
		else
			local eu = http.getenv("HTTP_AUTH_USER")
			local ep = http.getenv("HTTP_AUTH_PASS")
			if eu and ep and luci.sys.user.checkpasswd(eu, ep) then
				authen = function() return eu end
			end
		end
		if not util.contains(accs, user) then
			if authen then
				ctx.urltoken.stok = nil
				local user, sess = authen(luci.sys.user.checkpasswd, accs, def, superkey, randkey)
				if not user or not util.contains(accs, user) then
					return
				else
					local sid = sess or luci.sys.uniqueid(16)
					if not sess then
						local token = luci.sys.uniqueid(16)
						sauth.write(sid, util.get_bytecode({
							user=user,
							token=token,
							secret=luci.sys.uniqueid(16)
						}))
						ctx.urltoken.stok = token
					end
					luci.http.header("Set-Cookie", "sysauth=" .. sid.."; path="..build_url().."; httponly")
					ctx.authsession = sid
					ctx.authuser = user
				end
			else
				luci.http.status(403, "Forbidden")
				return
			end
		else
			ctx.authsession = sess
			ctx.authuser = user
		end
	end
	if track.setgroup then
		luci.sys.process.setgroup(track.setgroup)
	end
	if track.setuser then
		luci.sys.process.setuser(track.setuser)
	end
	local target = nil
	if c then
		if type(c.target) == "function" then
			target = c.target
		elseif type(c.target) == "table" then
			target = c.target.target
		end
	end
	if c and (c.index or type(target) == "function") then
		ctx.dispatched = c
		ctx.requested = ctx.requested or ctx.dispatched
	end
	if c and c.index then
		local tpl = require "luci.template"
		if util.copcall(tpl.render, "indexer", {}) then
			return true
		end
	end
	if type(target) == "function" then
		util.copcall(function()
			local oldenv = getfenv(target)
			local module = require(c.module)
			local env = setmetatable({}, {__index=
				function(tbl, key)
				return rawget(tbl, key) or module[key] or oldenv[key]
			end})
			setfenv(target, env)
		end)
		local ok, err
		if type(c.target) == "table" then
			ok, err = util.copcall(target, c.target, unpack(args))
		else
			ok, err = util.copcall(target, unpack(args))
		end
		assert(ok,
			"Failed to execute " .. (type(c.target) == "function" and "function" or c.target.type or "unknown") ..
			" dispatcher target for entry '/" .. table.concat(request, "/") .. "'.\n" ..
			"The called action terminated with an exception:\n" .. tostring(err or "(unknown)"))
	else
		local root = node()
		if not root or not root.target then
			error404("No root node was registered, this usually happens if no module was installed.\n")
		else
			error404("No page is registered at '/" .. table.concat(request, "/") .. "'.")
		end
	end
end
function createindex()
local path = luci.util.libpath() .. "/controller/"
local suff = { ".lua", ".lua.gz" }
createindex_plain(path, suff)
end
function createindex_fastindex(path, suffixes)
index = {}
if not fi then
fi = luci.fastindex.new("index")
for _, suffix in ipairs(suffixes) do
fi.add(path .. "*" .. suffix)
fi.add(path .. "*/*" .. suffix)
end
end
fi.scan()
for k, v in pairs(fi.indexes) do
index[v[2]] = v[1]
end
end
function createindex_plain(path, suffixes)
local controllers = { }--所有文件
for _, suffix in ipairs(suffixes) do
nixio.util.consume((fs.glob(path .. "*" .. suffix)), controllers)
nixio.util.consume((fs.glob(path .. "*/*" .. suffix)), controllers)
end
if indexcache then
local cachedate = fs.stat(indexcache, "mtime")
if cachedate then
local realdate = 0
for _, obj in ipairs(controllers) do
local omtime = fs.stat(obj, "mtime")
realdate = (omtime and omtime > realdate) and omtime or realdate
end
if cachedate > realdate then
assert(
sys.process.info("uid") == fs.stat(indexcache, "uid")
and fs.stat(indexcache, "modestr") == "rw-------",
"Fatal: Indexcache is not sane!"
)
index = loadfile(indexcache)()--加载对象缓存
return index
end
end
end
index = {}
for i,c in ipairs(controllers) do
local modname = "luci.controller." .. c:sub(#path+1, #c):gsub("/", ".")
for _, suffix in ipairs(suffixes) do
modname = modname:gsub(suffix.."$", "")
end
local mod = require(modname)
assert(mod ~= true,
"Invalid controller file found\n" ..
"The file '" .. c .. "' contains an invalid module line.\n" ..
"Please verify whether the module name is set to '" .. modname ..
"' - It must correspond to the file path!")
local idx = mod.index
assert(type(idx) == "function",
"Invalid controller file found\n" ..
"The file '" .. c .. "' contains no index() function.\n" ..
"Please make sure that the controller contains a valid " ..
"index function and verify the spelling!")
index[modname] = idx
end
if indexcache then
local f = nixio.open(indexcache, "w", 600)
f:writeall(util.get_bytecode(index))
f:close()
end
end
function createtree()
if not index then -- index 是所有 controller 下lua的集合数组包
createindex()
end
local ctx  = context
local tree = {nodes={}, inreq=true}
local modi = {}
ctx.treecache = setmetatable({}, {__mode="v"})
ctx.tree = tree
ctx.modifiers = modi
require "luci.i18n".loadc("base")
local scope = setmetatable({}, {__index = luci.dispatcher})
for k, v in pairs(index) do
scope._NAME = k
setfenv(v, scope)
v() -- 每个 lua文件的 function index 执行一次. 核心说明 http://luci.subsignal.org/trac/wiki/Documentation/ModulesHowTo
end
local function modisort(a,b)
return modi[a].order < modi[b].order
end
for _, v in util.spairs(modi, modisort) do
scope._NAME = v.module
setfenv(v.func, scope)
v.func()
end
return tree
end
function modifier(func, order)
context.modifiers[#context.modifiers+1] = {
func = func,
order = order or 0,
module = getfenv(2)._NAME
}
end
function assign(path, clone, title, order, noauth)
local obj  = node(unpack(path))
obj.nodes  = nil
obj.module = nil
obj.title = title
obj.order = order
obj.noauth = noauth
setmetatable(obj, {__index = _create_node(clone)})
return obj
end
function entry(path, target, title, order, noauth)
local c = node(unpack(path)) --unpack把数组作为一个可变参数进行传递
c.target = target
c.title  = title
c.order  = order
c.noauth = noauth
c.module = getfenv(2)._NAME
return c
end
function get(...)
return _create_node({...})
end
function node(...)
local c = _create_node({...})
c.module = getfenv(2)._NAME
c.auto = nil
return c
end
function _create_node(path)
if #path == 0 then
return context.tree
end
local name = table.concat(path, ".")--把数组通过字符串“.”连接起来
local c = context.treecache[name]
if not c then
local last = table.remove(path)--函数删除并返回table数组部分位于pos位置的元素. 其后的元素会被前移. pos参数可选, 默认为table长度, 即从最后一个元素删起.
local parent = _create_node(path)
c = {nodes={}, auto=true}
if parent.inreq and context.path[#path+1] == last then
c.inreq = true
end
parent.nodes[last] = c
context.treecache[name] = c --缓存
end
return c
end
function _firstchild()
local path = { unpack(context.path) }
local name = table.concat(path, ".")
local node = context.treecache[name]
local lowest
if node and node.nodes and next(node.nodes) then
local k, v
for k, v in pairs(node.nodes) do
if not lowest or
(v.order or 100) < (node.nodes[lowest].order or 100)
then
lowest = k
end
end
end
assert(lowest ~= nil,
"The requested node contains no childs, unable to redispatch")
path[#path+1] = lowest
dispatch(path)
end
function firstchild()
return { type = "firstchild", target = _firstchild }
end
function alias(...)
local req = {...}
return function(...)
for _, r in ipairs({...}) do
req[#req+1] = r
end
dispatch(req)
end
end
function rewrite(n, ...)
local req = {...}
return function(...)
local dispatched = util.clone(context.dispatched)
for i=1,n do
table.remove(dispatched, 1)
end
for i, r in ipairs(req) do
table.insert(dispatched, i, r)
end
for _, r in ipairs({...}) do
dispatched[#dispatched+1] = r
end
dispatch(dispatched)
end
end
local function _call(self, ...)
local func = getfenv()[self.name]
assert(func ~= nil,
'Cannot resolve function "' .. self.name .. '". Is it misspelled or local?')
assert(type(func) == "function",
'The symbol "' .. self.name .. '" does not refer to a function but data ' ..
'of type "' .. type(func) .. '".')
if #self.argv > 0 then
return func(unpack(self.argv), ...)
else
return func(...)
end
end
function call(name, ...)
return {type = "call", argv = {...}, name = name, target = _call}
end
local _template = function(self, ...)
require "luci.template".render(self.view)
end
function template(name)
return {type = "template", view = name, target = _template}
end
local function _arcombine(self, ...)
local argv = {...}
local target = #argv > 0 and self.targets[2] or self.targets[1]
setfenv(target.target, self.env)
target:target(unpack(argv))
end
function arcombine(trg1, trg2)
return {type = "arcombine", env = getfenv(), target = _arcombine, targets = {trg1, trg2}}
end
translate = i18n.translate
function _(text)
return text
end
function url_auth_append(url)
if type(url) == "string" then
return tostring(url):gsub("cgi%-bin/turbo","cgi%-bin/turbo" .. "/;stok=" .. luci.dispatcher.context.urltoken.stok .. "/")
elseif type(url) == "table" then
return tostring(url[1]):gsub("cgi%-bin/turbo","cgi%-bin/turbo" .. "/;stok=" .. luci.dispatcher.context.urltoken.stok .. "/")
else
return luci.dispatcher.build_url("admin_web","home")
end
end
function logger(str)
local logstr = fs.readfile("/tmp/wcy.log") or ""
fs.writefile("/tmp/wcy.log", logstr .. "\n" .. tostring(str))
end
function printTable(obj)
logger("printTable:")
for n, val in pairs(obj) do
if type(val)=="table" then
printTable(val)
else
logger("  "..n.."="..tostring(val))
end
end
end
