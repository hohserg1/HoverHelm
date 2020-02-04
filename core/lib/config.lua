return {enableLogger=true,terminal=true}


--[[
local fs=component.filesystem

fs.makeDirectory("/config")

local config={}

local function parse(type1,str)
	return type1=="string" and str
		or type1=="boolean" and  str=="true"
		or type1=="number" and tonumber(str)
		or str
end

function config.load(name,defaults)
	local cfgFileName="/config/"..name..".cfg"
	local r={}
	config[name]=r
	local cfgfile=readFile(cfgFileName)
	if cfgfile then
		for line in cfgfile:gmatch(".*\n?") do
			line=line:sub(line:find("[^%s]"))
			if line:sub(1,1)~="#" then
				local valueSeparator=line:find("=")
				local typeSeparator=line:find(":")
				local key,type1 = line:sub(1,typeSeparator-1),line:sub(typeSeparator+1,valueSeparator-1)
				r[key]=parse(type1,line:sub(separator+1))
				defaults[key]=nil
			end
		end
	end
	
	local f=fs.open(cfgFileName,"a")
	for k,v in pairs(defaults) do
		r[k]=v
		fs.write(table.concat({"\n",k,":",type(v),"=",tostring(v),"\n"}))
	end
	fs.close(f)
	
	return r
end

return config]]
