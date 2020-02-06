prn=prn or function()end

setmetatable(component,
    {
        __index=function(_,key)
            local a = component.list(key)()
            local r = a and component.proxy(a)
            component[key]=r
            return r
        end
    }
)

local eeprom=component.eeprom

local function split(str,separator)
    local r={}
    for ri in string.gmatch(str, "([^"..separator.."]+)") do
            table.insert(r, ri)
    end
    return table.unpack(r)
end

local function createPlainFilter(...)
    local pattern=table.pack(...)
    return function(...)
        local signal = table.pack(...)
            for i=1,pattern.n do
                if pattern[i] and signal[i]~=pattern[i] then
                    return false
                end
            end
        return true
    end
end


bios={}
local os_server_event_filter

local connector_type,address,port=split(eeprom.getData(),":")
bios.name=eeprom.getLabel()
local namedDevice=component.drone or component.robot
if namedDevice then
    bios.name=namedDevice.name()
    eeprom.setLabel(bios.name)
end
if connector_type=="modem" then
    port=tonumber(port)
    os_server_event_filter=createPlainFilter("modem_message",_,address,port)
    prn(address,port)
    local modem=component.modem
    modem.open(port)
    function bios.send(...)
        modem.send(address,port,...)
    end
elseif connector_type=="tunnel" then
    os_server_event_filter=createPlainFilter("modem_message")
    bios.send=component.tunnel.send
elseif connector_type=="stem" then
    --To do
end


local function pullInsensibly(filter)
    local queue={}
    local signal
    repeat
        signal = table.pack(computer.pullSignal(math.huge))
        table.insert(queue,signal)
    until filter(table.unpack(signal, 1, signal.n))

    for i=1,#queue-1 do
        local signal=queue[i]
        computer.pushSignal(table.unpack(signal, 1, signal.n))
    end

    return table.unpack(signal, 1, signal.n)
end

function bios.sendAwait(...)
    bios.send(...)
    local invokeResult = table.pack(pullInsensibly(os_server_event_filter))
    for i=1,5 do
        table.remove(invokeResult,1)
    end
    local ok = invokeResult[1]:match("result")
    if ok then
        table.remove(invokeResult,1)
        for i=1,invokeResult.n do
            if type(invokeResult[i])=="string" and string.sub(invokeResult[i],1,1)=="{" and string.sub(invokeResult[i],2,2)~=" " then
                invokeResult[i]=unserialize(invokeResult[i])
            end
        end

        return table.unpack(invokeResult)
    else
        error(""..invokeResult[2])
    end

end

local function loadFile(file,api)
    local handle, reason = api("open",file)
    if not handle then
        return error(reason)
    end
    local buffer = ""
    repeat
        local data = api("read",handle,math.huge)
        buffer = buffer .. (data or "")
    until not data
    api("close",handle)
    local ok,err = load(buffer, file)
    if not ok then
        error(err)
    end
    return ok()
end


bios.sendAwait("fs_connect",bios.name)
bios.fs_address=loadFile("/fs_client.lua",function(...)return bios.sendAwait("fs_component_invoke",...)end).fs_connect()


component.filesystem=component.proxy(bios.fs_address)
local fs=component.filesystem

loadFile("/init.lua",function(method,...)return fs[method](...)end)