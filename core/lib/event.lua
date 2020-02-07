local event={}

local handlers={}

function event.listen(event_name,handler)
    handlers[event_name]=handlers[event_name] or {}
    table.insert(handlers[event_name],handler)
end

local opullSignal=computer.pullSignal

computer.pullSignal=function(timeout)
    local signal=table.pack(opullSignal(timeout))

    local h=handlers[signal[1]]

    if h and #h>0 then
        for _, value in pairs(h) do
            pcall(value,table.unpack(signal))
        end
    end

    return table.unpack(signal)
end

function event.pull(...)
    local args=table.pack(...)
    local timeout, event_name
    if type(args[1])=="number" then
        timeout, event_name = args[1],args[2]
    else
        timeout, event_name = math.huge,args[1]
    end

    local start=computer.uptime()

    local signal
    repeat
        signal=table.pack(opullSignal(timeout))
    until not event_name or signal[1]==event_name or computer.uptime()-start>timeout

    return table.unpack(signal)
end

return event