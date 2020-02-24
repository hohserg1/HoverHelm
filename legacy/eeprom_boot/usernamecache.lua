local sfs = ...

local internalcache={}

if sfs.exists("/usernamecache") then
	local handle=sfs.open("/usernamecache","r")
	local r=""
	local chunk=sfs.read(handle,math.huge)
	while chunk do
		r = r..chunk
		chunk=sfs.read(handle,math.huge)
	end
	for line in r:gmatch("[^\r\n]+") do
		local separator=r:find("=")
		internalcache[line:sub(1,separator-1)]=line:sub(separator+1)
	end
end

local function writeUsernamePair(handle,address,login)
	sfs.write(handle,address)
	sfs.write(handle,"=")
	sfs.write(handle,login)
	sfs.write(handle,"\n")
end

local usernamecache=setmetatable({},{
	__index=function(_,key) return internalcache[key] end,
	__newindex=function(self,address,login)
		local exist = self[address]
		local handle = sfs.open("/usernamecache",exist and "w" or "a")
		internalcache[address]=login
		if not exist then
			writeUsernamePair(handle,address,login)
		else
			for k,v in pairs(internalcache) do
				writeUsernamePair(k,v)
			end
		end
		sfs.close(handle)
	end
})

return usernamecache