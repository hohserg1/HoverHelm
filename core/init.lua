local fs=component.filesystem

computer.pullSignal()

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


local libs={}

local function findLibrary(libname)
	local p1 = libname..".lua"
	local p2 = "/lib/"..libname..".lua"

	return fs.exists(p1) and p1
		or fs.exists(p2) and p2
		or error("lib not found: \""..libname.."\" at locations: {"..p1..", "..p2.."}")
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

function loadfile(path,name)
	name=name or path
	local code=readFile(path)
	if code then
		local l,err=load(code,name)
		if l then
			return l()
		else
			prn("err",err)
			error(err)
		end
	end
	return nil
end

require = cachedFunction(
	function(libname)
		return loadfile(findLibrary(libname))
	end
)

local config=require("system-config")

local function checkAndLoadLib(name)
	return config[name] and require(name)
end

prn("kek1")

require("log")

--checkAndLoadLib("event")
local terminal=checkAndLoadLib("terminal")

local currentProgram=coroutine.create(function()loadfile(".autorun.lua")end)
coroutine.resume(currentProgram)

if terminal then
	while true do
		terminal.tick()
	end
end


