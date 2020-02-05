local log={}

local config=require("system-config")

log.level={
	msg="msg",
	warn="warn",
	error="error"
}

function log.log(lvl, ...)
	local t=table.concat({...},", ")
	--table.concat({"[",timeMark(),"]","[",lvl,"]",...},", ").."\n"
	send("log.log",timeMark(),lvl,t)
end

local leveledPrint = config.enableLogger and (function(lvl) return function(...) log.log(lvl,...) end end)
										  or (function() return function() end end)

log.msg=leveledPrint(log.level.msg)
log.warn=leveledPrint(log.level.warn)
log.error=leveledPrint(log.level.error)

local oerror=error
error=function(e,l)
	log.error(e)
	log.error(debug.traceback())
	oerror(e,(l or 1)+1)
end

return log