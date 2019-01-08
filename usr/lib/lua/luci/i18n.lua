require("luci.util")
module("luci.i18n", package.seeall)
table   = {}
loaded  = {}
context = luci.util.threadlocal()
default = "zh_cn"
function clear()
table = {}
end
function load(file, lang, force)
lang = lang and lang:gsub("_", "-") or ""
if context.lang ~= lang then
lang = context.lang
end
if lang=="zh-cn" then
require "luci.i18n_zh_cn"
table["zh-cn"] = luci.i18n_zh_cn.dict
elseif lang=="en" then
require "luci.i18n_eng"
table["en"] = luci.i18n_eng.dict
end
return true
end
function loadc(file, force)
local ok = load(file, default, force)
if ok then
return ok
end
if context.parent then
ok = load(file, context.parent, force)
if ok then
return ok
end
end
return load(file, context.lang, force)
end
function setlanguage(lang)
context.lang   = lang:gsub("_", "-")
context.parent = (context.lang:match("^([a-z][a-z])_"))
end
function translate2(key)
return key
end
function translate(key)
return (table[context.lang] and table[context.lang][key])
or (table[context.parent] and table[context.parent][key])
or (table[default] and table[default][key])
or key
end
function translatef(key, ...)
return tostring(translate(key)):format(...)
end
function string(key)
return tostring(translate(key))
end
function stringf(key, ...)
return tostring(translate(key)):format(...)
end
