local event={}

local handlers={}

function event.listen(event_name,handler)
    handlers[event_name]=handler
end

function event.pull(event_name)
    local signal
    repeat
        signal=table.pack(computer.pullSignal(math.huge))
        local h=handlers[signal[1]]
        if h then
            h(table.unpack(signal))
        end
    until signal[1]==event_name
    return table.unpack(signal)
end

return event