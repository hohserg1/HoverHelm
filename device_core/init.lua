println("It work!")
--[[
local function cachedFunction(f)
   return setmetatable({},{
        __call=function(self,arg)return self[arg] end, 
        __index=function(self,arg)
            local r = f(arg)
            self[arg]=r
            return r
        end
    })
end

local function cachedFunction(f)
    local cache = {}
    return function(arg)
        local r = cache[arg]
        if not r then
            r = f(arg)
            cache[arg] = r
        end
        return r
    end
end
--]]
os=os or {}

function os.cachedFunction(f, cache)
	cache = cache or {}

	local function evaluate(arg)
		local r=f(arg)
		cache[arg]=r
		return r
	end

	return function(arg)
		return cache[arg] or evaluate(arg)
	end,cache
end

local fs=component.filesystem

function os.findFileIn(filename,...)
	local places=table.pack(...)
	for _, value in pairs(places) do
		local candidate=value.."/"..filename
		if fs.exists(value.."/"..filename) then
			return candidate
		end
	end
	error("file not found: \""..filename.."\" at locations: {"..table.concat(
        mapSeq(places,function(place)return "\""..place.."\"" end)
    ,", ").."}")
end


function os.readFile(filename)
	local f, err = fs.open(filename,"r")
	if f then
		local r=""
		local chunk=fs.read(f,math.huge)
		while chunk do
			r=r..chunk
			chunk=fs.read(f,math.huge)
		end

		return r
	else
		return nil, err
	end
end

function loadfile(path,name,...)
	name = name or path
	local code, err = os.readFile(path)
	if code then
		local l,err = load(code,name)
		if l then
			return l
		else
            return nil, err
		end
	else
        return nil, err
    end
end

local function findLibrary(libname)
	return os.findFileIn(libname..".lua", "/", "/lib/")
end

require = os.cachedFunction(
	function(libname)
		local l, err = loadfile(findLibrary(libname),libname)
        if l then
            return l()
        else
            error(err)
        end
	end, _G
)

require"config"
require"utils"
require"log"
require"terminal"

log.print(bios.name.." started")

function os.executeProgram(name, ...)
    local path = os.findFileIn(name..".lua", "/", "/programs/")
    local l, err = loadfile(path,name)
    if l then
        l(...)
    else
        error(err)
    end
end

println(fs.list("/"))

--main cycle
local ok, err = xpcall(function()
    if config.autorun then
        os.executeProgram(config.autorun)
    end

    while true do
        local input = {split(terminal.read()," ")}
        local ok, err = xpcall(os.executeProgram, debug.traceback, input[1],table.unpack(input,2))
        
        if not ok then
            log.error(err)
        end
    end
end,debug.traceback)

if not ok then
    log.error(err)
end

log.close()

computer.shutdown(not ok)