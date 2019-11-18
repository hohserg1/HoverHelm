--config
local netComponentName = "tunnel"
local address,port = "",""

--

local event=require("event")
local component=require("component")
local serialization=require("serialization")

--net
local net=component[netComponentName]

local maxPacketSize=net.maxPacketSize()

local function send(...)
	net.send(...)
end
--

--specials
local specials={}

local function bindSpecial(value)
	local index=#specials+1
	specials[index]=value
	return index
end

local function unbindSpecial(index)
	specials[index]=nil
end

local function specialByIndex(index)
	return specials[index]
end
--

local work=true

local reactions={
	["component.primary"] = 
		function(ctype)
			local r=component.list(ctype)()
			--print("primaryResult", r)
			send("primaryResult", "e6d4e5c6-4f33-41c8-ae2c-e317a826714a")
		end,
	["component.invoke"] = 
		function(address, method, ...)
			local args={...}
			local specialIndex=0
			for i=0,#args do
				if(type(args[i])=="string") and string.sub(args[i],1,9)=="{special=" then
					specialIndex=tonumber(string.sub(args[i],10,-2))
					args[i]=specialByIndex(specialIndex)
				end			
			end
			local r={component.proxy(address)[method](table.unpack(args))}
			for i=0,#r do
				if type(r[i])=="table" then
					local nr=serialization.serialize(r[i])
					if nr=="{type=\"userdata\"}" then
						nr="{special="..bindSpecial(r[i]).."}"
					end
					r[i]=nr
				end			
			end
			os.sleep(0.05)
			print("invokeResult", r)
			send("invokeResult",table.unpack(r))
			
			if(method=="close")then
				unbindSpecial(specialIndex)
			end
		end,
	["specials.unbind"]=
		function(index)
			unbindSpecial(index)
		end
}

local function eventHandler(_, _, from, port, _, request, ...)
	print("received message", request, ...)
	reactions[request](...)
end

while work do
	eventHandler(event.pull("modem_message"))
end