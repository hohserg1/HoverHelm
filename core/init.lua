local fs=component.filesystem

function cachedFunction(f)
	local cache={}

	local function evaluate(arg)
		local r=f(arg)
		cache[arg]=r
		return r
	end

	return function(arg)
		return cache[arg] or evaluate(arg)
	end,cache
end

table.map=function(t,f)
    local r={}
    for key, value in pairs(t) do
        r[key]=f(value)
    end
    return r
end

local libs={}

function findFileIn(filename,...)
	local places=table.pack(...)
	for _, value in pairs(places) do
		local candidate=value.."/"..filename
		if fs.exists(value.."/"..filename) then
			return candidate
		end
	end
	error("file not found: \""..libname.."\" at locations: {"..table.concat(places,", ").."}")
end

local function findLibrary(libname)

	return findFileIn(libname..".lua","/","/lib/")
end

function readFile(filename)
	local f=fs.open(filename,"r")
	if f then
		local r=""
		local chunk=fs.read(f,math.huge)
		while chunk do
			r=r..chunk
			chunk=fs.read(f,math.huge)
		end

		return r
	else
		return nil
	end
end

function loadfile(path,name,...)
	name=name or path:sub((path:find("/",-1) or 0)+1)
	local code=readFile(path)
	if code then
		local l,err=load(code,name)
		if l then
			return l(...)
		else
			prn("err",err)
			error(err)
		end
	end
	return nil
end

require = cachedFunction(
	function(libname)
		local r = loadfile(findLibrary(libname))
		_G[libname]=r
		return r
	end
)

local config=require("system-config")

local function require_if_enabled(name)
	return config[name] and require(name)
end

function os.run_program(filename,...)
	os.current_program=fs_client.canonical(filename)
    loadfile(filename,os.current_program,...)
    os.current_program=nil
end

require("log")
require("event")

require_if_enabled("terminal")

event.listen("modem_message",function(_,receiverAddress, senderAddress, port, distance,cmd,...)
	if senderAddress==bios.address and port==bios.port then
		computer.pushSignal("os_server_message",cmd,...)
	end
end)

local autorun_file_name="/.autorun.lua"
if fs.exists(autorun_file_name) then
	os.current_program=autorun_file_name
	loadfile(autorun_file_name)
end

while true do
	computer.pullSignal(math.huge)
end


