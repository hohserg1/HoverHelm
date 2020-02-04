local terminal={}

local sfs,send=...

local addressByName={}
local nameByAddress={}

local devicesByName={}

local viewerByDevice={}
local deviceByViewer={}

local function newDevice()
	return {log={}}
end

function terminal.init(sender,actualName)
	addressByName[actualName]=sender
	nameByAddress[sender]=actualName
	devicesByName[actualName]=newDevice()
end

function terminal.attach_view(sender,deviceName)
	if addressByName[deviceName] then
		local v=(viewerByDevice[deviceName] or {})
		deviceByViewer[sender]=deviceName
		
		v[sender]=true
		
		viewerByDevice[deviceName]=v
	end
end

local function currentTimeMark()

end

local function logByName(deviceName, timeMark, lvl, msg)
	local log=devicesByName[deviceName].log
	local newLine=table.concat({"[",timeMark,"]","[",lvl,"]",msg}," ").."\n"
	table.insert(log,newLine)
	for k in pairs(viewerByDevice[deviceName]) do
		send(k,"hover.log",newLine)
	end
end

function terminal.execute(sender, cmd)
	local deviceName=deviceByViewer[sender]
	local deviceAddress=addressByName[deviceName]
	logByName(deviceName, currentTimeMark(),">",cmd)
	send(deviceAddress,"executeCommand",cmd)
end

function terminal.log(sender, timeMark,lvl,msg)
	logByName(nameByAddress[sender])
end

return terminal