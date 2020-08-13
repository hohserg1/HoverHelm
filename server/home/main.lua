function hh_module(name)
    return require("hoverhelm."..name)
end

local event=require"event"
local component=require"component"
local filesystem=require"filesystem"
local utils=hh_module"utils"

local handlers={}

do
    print("HoverHelm init...")
    
    local function prepareHandler(handler,moduleName, handlerName)
        return setmetatable({handler,description=moduleName.."."..handlerName},{__call=function(self, ...)return self[1](...)end})
    end
    
    local temp = collect(filesystem.list("/home/lib/hoverhelm/"))
    table.sort(temp)
    foreach(temp,function(_,filename) 
        if filename:sub(-4)==".lua" then
            local modulename = filename:sub(1, -5)
            --print(modulename)
            local module = hh_module(modulename)
            _G[modulename]=module
            foreach(module.handlers or {}, function(k,handler)
                --print(" ",k)
                handlers[k]=handlers[k] or {}
                table.insert(handlers[k],prepareHandler(handler,modulename,k))
            end)
        end
    end)
    os.sleep(5)
end


local networkCards = 
    map(config.inUseNetworkCards,function(address,cfg)
        local card = component.proxy(address)
        return address, {send = 
            card.type == "modem" and (function(to, ...)return card.send(to, cfg.port, ...)end) or
            card.type == "tunnel" and (function(to, ...)return card.send(...)end)
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
        local args = table.pack(...)
        foreach(handlers[msg],  function(_,handler)
            local ok, err = pcall(handler,card, senderAddress,table.unpack(args))
            if not ok then 
                terminal.noticeLocalLog(terminal.log_level.err, "Exception on calling handler "..handler.description..err)
                terminal.noticeLocalLog(terminal.log_level.err, "   "..err)
            end
        end)
    end

    
end)

terminal.startLocalTerminal()