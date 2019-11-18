local log={}

local fs=component.filesystem

fs.makeDirectory("/logs")

local latestName="/logs/latest.log"

if fs.exists(latestName) then
	fs.rename(latestName,"/logs/"..fs.lastModified(latestName)..".log")
end

local logfile=component.filesystem.open(latestName,"a")

local msg={type="msg"}
local warn={type="warn"}
local error={type="error"}

log.level={
	msg=msg,
	warn=warn,
	error=error
}

function log.log(lvl, ...)
	local t=table.concat({timeMark(),"[",lvl,"]",...},", ").."\n"
	fs.write(logfile,t)
end

local function leveledPrint(lvl) return function(...) log.log(lvl,...) end end

log.msg=leveledPrint(msg)
log.warn=leveledPrint(warn)
log.error=leveledPrint(error)

return log