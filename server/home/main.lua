function hh_module(name)
	return require("hoverhelm."..name)
end

local event=require"event"
local component=require"component"
local filesystem=require"filesystem"

local handlers={}

for filename in filesystem.list("/home/lib/hoverhelm/") do
	if filename:sub(-4)==".lua" then
		local module = hh_module(filename:sub(1, -5))
		foreach(module.handlers, function(k,handler)
			if k == "hh_connect" then
				print(filename)
			end
			handlers[k]=handlers[k] or {}
			table.insert(handlers[k],handler)
		end)
	end
end

local terminal=hh_module"terminal"

local networkCards = 
	map(config.inUseNetworkCards,function(address,cfg)
		local card = component.proxy(address)
		return address, {send = 
			card.type == "modem" and (function(to, ...)card.send(to, cfg.port, ...)end) or
			card.type == "tunnel" and (function(to, ...)card.send(...)end)
			--todo: stem support
		}	
	end)
	
foreach(config.inUseNetworkCards,function(address,cfg)
	pcall(component.invoke,address,"open",cfg.port)
end)


--todo: stem support
hoverhelmModemMessageHandler = event.listen("modem_message",function(_,receiverAddress, senderAddress, port, distance, msg, ...)

	if config.inUseNetworkCards[receiverAddress] and config.inUseNetworkCards[receiverAddress].port == port then
		local card = networkCards[receiverAddress]
		foreach(handlers[msg],  function(_,handler)
			handler(card, senderAddress,...)
		end)
	end

	
end)

terminal.startLocalTerminal()