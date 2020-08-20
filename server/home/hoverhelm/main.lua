function hh_module(name)
    return require("hoverhelm."..name)
end

local event=require"event"
local component=require"component"
local filesystem=require"filesystem"
local utils=hh_module"utils"

hoverhelm = {
    init = false,
    handlers={},
    modemMessageHandler = nil
}

local function init()
    print("HoverHelm init...")
    
    local handlers = hoverhelm.handlers
    
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
    
    hoverhelm.networkCards = 
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
    hoverhelm.modemMessageHandler = event.listen("modem_message",function(_,receiverAddress, senderAddress, port, distance, msg, ...)
    
        if config.inUseNetworkCards[receiverAddress] and config.inUseNetworkCards[receiverAddress].port == port then
            local card = hoverhelm.networkCards[receiverAddress]
            local args = table.pack(...)
            --os.sleep(1)
            foreach(handlers[msg],  function(_,handler)
                terminal.noticeLocalLog(terminal.log_level.debug, "call "..handler.description)
                local ok, err = pcall(handler,card, senderAddress,table.unpack(args))
                if not ok then
                    terminal.noticeLocalLog(terminal.log_level.error, "Exception on calling handler "..handler.description)
                    terminal.noticeLocalLog(terminal.log_level.error, "   "..err)
                end
            end)
        end

        
    end)
    
    hoverhelm.init=true
end

function hoverhelm.stop()
    event.cancel(hoverhelm.modemMessageHandler)
    hoverhelm=nil
    terminal.noticeLocalLog(terminal.log_level.msg, "HoverHelm server finished")
    os.exit()
end

function hoverhelm.hide()
    terminal.noticeLocalLog(terminal.log_level.msg, "HoverHelm server hided")
    os.exit()
end

if not hoverhelm.init then
    init()
end
terminal.startLocalTerminal()