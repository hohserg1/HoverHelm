local function cachedFunction(f)
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

print=prn

local primaryComponent do
	local primaryCache
	primaryComponent,primaryCache=cachedFunction(function(componentType) return component.proxy(component.list(componentType)()) end)
	for address in component.list("filesystem") do
		local label=component.invoke(address,"getLabel")
		if label~="tmpfs" then
			primaryCache["filesystem"]=component.proxy(address)
			break
		end
	end
end

setmetatable(component,{__index=function(_,key) return primaryComponent(key) end})
local fs=component.filesystem


local libs={}

local function findLibrary(libname)
	local p1 = "/"..libname..".lua"
	local p2 = "/lib"..p1
	
	return fs.exists(p2) and p2
		or fs.exists(p1) and p1
		or error("file not found: "..libname)
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

require=cachedFunction(
	function(libname)
		local path,err=findLibrary(libname)
		print(path,err)
		local code=readFile(path)
		if code then
			local l,err=load(code,libname)
			if l then
				return l()
			else
				print("err",err)
			end
		end
		return nil
	end
)

local config=require("system-config")

local function checkAndLoadLib(name)
	return config[name] and require(name)
end

require("log")

checkAndLoadLib("terminal")