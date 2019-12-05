local log={}

local fs=component.filesystem
local config=require("system-config")

if fs.exists(latestName) then
	fs.rename(latestName,"/logs/"..fs.lastModified(latestName)..".log")
end

local logfile=component.filesystem.open(latestName,"a")

local msg="msg"
local warn="warn"
local error="error"

log.level={
	msg=msg,
	warn=warn,
	error=error
}

function log.log(lvl, ...)
	local t=table.concat({...},", ")
	--table.concat({"[",timeMark(),"]","[",lvl,"]",...},", ").."\n"
	send("log.log",timeMark(),lvl,t)
end

local leveledPrint = config.enableLogger and (function(lvl) return function(...) log.log(lvl,...) end end) 
										  or (function() return function() end end)

log.msg=leveledPrint(msg)
log.warn=leveledPrint(warn)
log.error=leveledPrint(error)

return log